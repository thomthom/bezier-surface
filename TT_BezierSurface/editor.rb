#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # Manages the editing environment for bezier patches.
  #
  # The cless is a Tool class, used as the root for the editing tools. This
  # class must be activated first - then the sub-tools are pushed into the
  # stack.
  #
  # @since 1.0.0
  class BezierSurfaceEditor    
    
    attr_reader( :model, :surface, :selection, :draw_cache )
    
    def initialize( model )
      @model = model
      @selection = Selection.new( self )
      @surface = nil
      
      @active_tool = nil
      @active = false
      
      @selection.add_observer( BST_SelectionObserver.factory )
      
      # Drawing Performance Test ( 23.05.2011 )
      #   14 Patches - 12 Subdivisions
      #
      #   Without Cache: ~0.100s
      #   With Cache:    ~0.005s
      #
      # In addition to the raw numbers, the user experience felt much smoother
      # with the cache.
      @draw_cache = DrawCache.new( @model.active_view )
    end
    
    # Indicates if there is an active edit session.
    #
    # @return [Boolean]
    # @since 1.0.0
    def active?
      @active == true
    end
    
    # Activates Bezier Surface editing mode.
    # Used when a bezier surface group or component is opened for editing.
    #
    # @param [Sketchup::Group|Sketchup::ComponentInstance] instance
    #
    # @return [Boolean]
    # @since 1.0.0
    def edit( instance )
      TT.debug( 'BezierSurfaceEditor.edit' )
      # Don't activate a new session while there is one already active.
      if @active
        TT.debug( '> Already active edit session!' )
        return false
      end
      @surface = BezierSurface.load( instance )
      if @surface
        # Clear native selection for less visual distraction and avoid
        # tools performing actions on the selection. (Such as the Delete key.)
        @model.selection.clear
        # Activate Bezier Surface editing mode.
        @model.select_tool( nil ) # Ensure no other tool is active.
        @model.tools.push_tool( self )
        # Start observing the surface for changes.
        @surface.clear_observers! # Just to be safe.
        @surface.add_observer( BST_SurfaceObserver.factory )
        # Activate sub-tool.
        tool = SelectionTool.new( self )
        select_tool( tool )
      else
        # Invalid instance or incompatible version
        puts 'Invalid Bezier Surface or incompatible version.'
        model.close_active # (?)
      end
      true
    end
    
    # Adds standard context menu items.
    #
    # @param [Sketchup::Menu] instance
    #
    # @return [Sketchup::Menu]
    # @since 1.0.0
    def context_menu( menu )
      patches_selected = @selection.any?{ |e|
        e.is_a?( BezierPatch )
      }
      
      # Patches
      if patches_selected
        m = menu.add_item( 'Automatic Interior' ) { toggle_automatic_patch() }
        menu.set_validation_proc( m ) { validate_automatic_patch() }
        
        menu.add_separator
      end
      
      menu.add_item( 'Select All' ) {
        @selection.add( @surface.manipulable_entities )
      }
      
      menu.add_item( 'Select None' ) {
        @selection.clear
      }
      
      menu.add_item( 'Invert Selection' ) {
        @selection.toggle( @surface.manipulable_entities )
      }
      
      menu.add_separator
      
      submenu = menu.add_submenu( 'Select' )
      
        m = submenu.add_item( 'Vertices' ) { puts 'Vertices' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_CHECKED }
        
        m = submenu.add_item( 'Handles' ) { puts 'Handles' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_UNCHECKED }
        
        m = submenu.add_item( 'Edges' ) { puts 'Patches' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_CHECKED }
        
        m = submenu.add_item( 'Patches' ) { puts 'Patches' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_CHECKED }
      
      
      submenu = menu.add_submenu( 'Display' )
      
        m = submenu.add_item( 'All Handles' ) { puts 'n01' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_UNCHECKED }
        
        m = submenu.add_item( 'Automatic Interior' ) { puts 'n02' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_CHECKED }
      
      
      menu.add_separator
      
      menu.add_item( 'Close Instance' ) { end_session() }
      
      menu
    end
    
    # Activates a bezier editing tool - pushing it into SketchUp's tool stack.
    #
    # @param [Sketchup::Tool] tool
    #
    # @return [Boolean]
    # @since 1.0.0
    def select_tool( tool )
      # (!) Some times other tools, for instance viewport tools, push other
      #     tools into the stack. This should be accounted for so we get a 
      #     correctly working tool stack.
      TT.debug( 'BezierSurfaceEditor.select_tool' )
      if @active_tool
        TT.debug( '> Pop active tool...' )
        @model.tools.pop_tool
      end
      TT.debug( '> Push new tool...' )
      @active_tool = tool
      @model.tools.push_tool( tool )
    end
    
    # Ends the active editing session. Called when the bezier surface instance
    # is closed or when the user activates another tool.
    #
    # When the user activates another tool the open bezier instance is closed.
    #
    # @return [Boolean]
    # @since 1.0.0
    def end_session
      # (!) Ensure all tools are popped. Some times other tools might have
      #     pushed a tool into the stack.
      TT.debug( 'BezierSurfaceEditor.end_session' )
      if @active
        TT.debug( '> Ending active tool...' )
        if @active_tool
          TT.debug( '  > Pop sub-tool...' )
          @model.tools.pop_tool
        end
        TT.debug( '  > Pop self...' )
        @model.tools.pop_tool
      end
    end
    
    # Forwards message to active_tool.
    #
    # @return [Nil]
    # @since 1.0.0
    def refresh_viewport
      update_viewport_cache()
      if @active_tool.respond_to?( :refresh_viewport )
        @active_tool.refresh_viewport
      end
      update_properties()
      nil
    end
    
    # @since 1.0.0
    def update_properties
      types = {}
      for e in @selection
        types[ e.class ] ||= []
        types[ e.class ] << e
      end
      names = {
        PLUGIN::BezierVertex => 'Vertices',
        PLUGIN::BezierHandle => 'Handles',
        PLUGIN::BezierInteriorPoint => 'InteriorPoints',
        PLUGIN::BezierEdge => 'Edges',
        PLUGIN::QuadPatch => 'Patches'
      }
      info = "Entity Info\n"
      types.each { |type, entities|
        info += "#{entities.size} #{names[type]}\n"
      }
      if types[ PLUGIN::BezierEdge ] 
        length = 0.mm
        for edge in types[ PLUGIN::BezierEdge ] 
          length += edge.length( @surface.subdivs )
        end
        info += "\nLength: #{length.to_l.to_s}"
      end
      PLUGIN::PropertiesWindow.info = info
    end
    
    # (!) Move to BezierSurface ?
    #
    # Changes the subdivision of the active surface and commits it.
    #
    # @param [Integer] subdivs
    #
    # @return [Boolean]
    # @since 1.0.0
    def change_subdivisions( subdivs )
      if subdivs > 0 && subdivs != @surface.subdivs
        @model.start_operation( 'Change Subdivisions', true )
        @surface.subdivs = subdivs
        @surface.update
        @model.commit_operation
        true
      else
        false
      end
    end
    
    # Checks if the current model context is a bezier surface.
    #
    # @return [Boolean]
    # @since 1.0.0
    def valid_context?
      (@model.active_path.nil?) ? false : @model.active_path.last == @surface.instance
    end
    
    # Called by the BST_ModelObserver observer when something is undone or
    # redone.
    #
    # When editing is active the mesh is refreshed, otherwise the active 
    # editing session is ended.
    #
    # @return [Nil]
    # @since 1.0.0
    def undo_redo
      TT.debug( 'BezierSurfaceEditor.undo_redo' )
      if valid_context?
        @surface.reload
        @selection.clear # SelectionObserver refreshes the viewport.
        # (?) Should the selection just remove invalid entities?
      else
        TT.debug( '> Invalid Context' )
        self.end_session
      end
      nil
    end
    
    # @return [String]
    # @since 1.0.0
    def inspect
      "#<#{self.class.name}:#{TT.object_id_hex( self )}>"
    end
    
    # Creates and displays the bezier surface editing toolbar.
    #
    # @return [Boolean]
    # @since 1.0.0
    def show_toolbar
      if @toolbar.nil?
        options = {
          :title => PLUGIN_NAME,
          :pref_key => "#{PLUGIN::ID}_Toolbar",
          :left => 200,
          :top => 200,
          :width => 280,
          :height => 50,
          :resizable => false,
          :scrollable => false
        }
        @toolbar = TT::GUI::ToolWindow.new( options )
        @toolbar.theme = TT::GUI::Window::THEME_GRAPHITE # (!) Add as option
        #@toolbar.add_script( File.join(PATH_UI, 'js', 'wnd_toolbar.js') )
        @toolbar.add_style( File.join(PATH_UI, 'css', 'wnd_toolbar.css') )
        
        # Select
        button = TT::GUI::ToolbarButton.new('Select') {
          TT.debug 'Tool: Select'
          tool = SelectionTool.new( self )
          select_tool( tool )
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'Select_24.png' )
        @toolbar.add_control( button )
        
        # Move
        button = TT::GUI::ToolbarButton.new('Move') {
          TT.debug 'Tool: Move'
          tool = MoveTool.new( self )
          select_tool( tool )
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'Move_24.png' )
        @toolbar.add_control( button )
        
        # Add QuadPatch
        button = TT::GUI::ToolbarButton.new('Add QuadPatch') {
          TT.debug 'Add QuadPatch'
          Operations.add_quadpatch
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'QuadPatch_24.png' )
        @toolbar.add_control( button )
        
        # Add TriPatch
        button = TT::GUI::ToolbarButton.new('Add TriPatch') {
          TT.debug 'Add TriPatch'
          #PLUGIN.add_tripatch # (!)
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'TriPatch_24.png' )
        @toolbar.add_control( button )
        
        # Axis
        container = TT::GUI::Container.new
        list = TT::GUI::Listbox.new( [
          'Local',
          'Parent',
          'Global',
          'Selection',
          'Custom'
        ] )
        list.on_change { |value|
          TT.debug "Axis: #{value}"
          TT::SketchUp.activate_main_window
        }
        label = TT::GUI::Label.new( 'Axis: ', list )
        container.add_control( label )
        container.add_control( list )
        @toolbar.add_control( container )
        
      end
      @toolbar.show_window
      
      TT::SketchUp.activate_main_window
    end
    
    # Closes the bezier surface editing toolbar.
    #
    # @return [Nil]
    # @since 1.0.0
    def close_toolbar
      @toolbar.close if @toolbar.visible?
      nil
    end
    
    ### Tool Events
    
    # @since 1.0.0
    def activate
      TT.debug( 'BezierSurfaceEditor.activate' )
      @active = true
      @active_tool = nil
      @selection.clear
      
      # UI
      show_toolbar()
    end
    
    # @since 1.0.0
    def deactivate(view)
      TT.debug( 'BezierSurfaceEditor.deactivate' )
      @active = false
      @active_tool = nil
      
      close_toolbar()
      
      # (!) SketchUp bug!
      # Sketchup.close_active
      # Normally, closing a group/component appears in the undo stack.
      # But when close_active is used in SU8-M1 and older the action does not
      # appear in the stack - so when you then trigger undo/redo after using
      # this method all the modified geometry is offset.
      if valid_context?
        TT.debug( '> Closing active context' )
        view.model.close_active
      end
      
      #@selection.remove_observer( BST_SelectionObserver.factory )
      #@surface.remove_observer( BST_SurfaceObserver.factory )
      @surface.clear_observers!
      
      # Clean up any object references so they can be garbage collected.
      @selection.clear
      @surface = nil
      @draw_cache.clear
    end
    
    private
    
    # @return [Boolean]
    # @since 1.0.0
    def toggle_automatic_patch
      automatic = ( validate_automatic_patch == MF_CHECKED ) ? false : true
      for patch in @selection.patches.to_a
        patch.automatic = automatic
        # Remove selected interior points from selection when making patch
        # automatic since the user should not be interacting with these points.
        if automatic
          @selection.remove( patch.interior_points )
        end
      end
      model = @model
      model.active_view.refresh
      TT::Model.start_operation( 'Automatic Interior' )
      @surface.update
      model.commit_operation
      automatic
    end
    
    # Returns MF_CHECKED if any patch in selection has automatic interior.
    #
    # @return [MF_CHECKED,MF_UNCHECKED]
    # @since 1.0.0
    def validate_automatic_patch
      for patch in @selection.patches
        return MF_CHECKED if patch.automatic?
      end
      MF_UNCHECKED
    end
    
    # @return [Nil]
    # @since 1.0.0
    def update_viewport_cache
      # (?) Make public so sub-tools can force an update?
      @draw_cache.clear
      view = @draw_cache
      
      tr = view.model.edit_transform
      
      selected_vertices = @selection.vertices
      selected_interior = @selection.interior_points
      selected_edges = @selection.edges
      selected_patches = @selection.patches
      
      unselected_vertices = @surface.vertices - selected_vertices
      unselected_interior = @surface.manual_interior_points - selected_interior
      unselected_edges = @surface.edges - selected_edges
      
      # Get selected vertices and selected entities' vertices. Display handles
      # for each vertex.
      active_vertices = @selection.to_vertices
      
      # Draw patches last because it uses transparent colour. SketchUp seem to
      # cull out any opaque drawing that happens after transparent drawing.
      @surface.draw_internal_grid( view )
      @surface.draw_edges( view, unselected_edges )
      @surface.draw_edges( view, selected_edges, true )
      @surface.draw_vertices( view, unselected_vertices )
      @surface.draw_vertices( view, selected_vertices, true )
      @surface.draw_vertex_handles( view, active_vertices )
      @surface.draw_vertices( view, unselected_interior )
      @surface.draw_vertices( view, selected_interior, true )
      @surface.draw_automatic_interior( view )
      @surface.draw_patches( view, selected_patches )
      nil
    end
    
  end # class BezierSurfaceEditor
  
end # module TT::Plugins::BezierSurfaceTools