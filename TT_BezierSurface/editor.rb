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
    
    attr_reader( :model, :surface, :selection )
    
    def initialize( model )
      @model = model
      @selection = Selection.new
      @surface = nil
      
      @active_tool = nil
      @active = false
    end
    
    # Indicates if there is an active edit session.
    #
    # @return [Boolean]
    # @since 1.0.0
    def active?
      #TT.debug( 'BezierSurfaceEditor.active?' )
      #TT.debug( "> #{@active}" )
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
        @model.selection.clear
        @model.select_tool( nil ) # Ensure no other tool is active.
        @model.tools.push_tool( self )
        tool = VertexSelectionTool.new( self )
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
      menu.add_separator
      
      m = menu.add_item( 'Show All Handles' ) { puts 'n01' }
      menu.set_validation_proc( m ) { MF_GRAYED }
      
      m = menu.add_item( 'Show Interior' ) { puts 'n02' }
      menu.set_validation_proc( m ) { MF_GRAYED }
      
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
      if subdivs > 0
        @model.start_operation('Change Subdivisions', true)
        @surface.subdivs = subdivs
        @surface.update( @model.edit_transform )
        @model.commit_operation
        true
      else
        false
      end
    end
    
    # (!) Private method in BezierSurface
    #
    # Converts a transformation for the global space into a transformation
    # within the local space.
    #
    # Use when editing a bezier surface. The group will be open and the
    # co-ordinate system in SketchUp is working in world space.
    #
    # @param [Geom::Transformation] transformation
    #
    # @return [Boolean]
    # @since 1.0.0
    def local_transformation( transformation )
      # Cast Vector3d into Transformation.
      if transformation.is_a?( Geom::Vector3d )
        transformation = Geom::Transformation.new( transformation )
      end
      et = @model.edit_transform
      local_transform = (et.inverse * transformation) * et
    end
    
    # Checks if the current model context is a bezier surface.
    #
    # @return [Boolean]
    # @since 1.0.0
    def valid_context?
      (@model.active_path.nil?) ? false : @model.active_path.last == @surface.instance
    end
    
    # Called by the BP_ModelObserver observer when something is undone or
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
        @selection.clear
      else
        TT.debug( '> Invalid Context' )
        self.end_session
      end
      nil
    end
    
    # Draw mesh grids and control points.
    #
    # @param [Sketchup::View] view
    # @param [Boolean] preview
    #
    # @return [Nil]
    # @since 1.0.0
    def draw( view, preview = false )
      return unless @surface
      @surface.draw_internal_grid( view, preview )
      @surface.draw_control_grid( view )
      @surface.draw_control_points( view, @selection.to_a )
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
        @toolbar.theme = TT::GUI::Window::THEME_GRAPHITE
        #@toolbar.add_script( File.join(PATH_UI, 'js', 'wnd_toolbar.js') )
        @toolbar.add_style( File.join(PATH_UI, 'css', 'wnd_toolbar.css') )
        
        # Select Vertex
        button = TT::GUI::ToolbarButton.new('Select Control Points') {
          puts 'Tool: Select Control Points'
          tool = VertexSelectionTool.new( self )
          select_tool( tool )
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'Select_24.png' )
        @toolbar.add_control( button )
        
        # Select
        button = TT::GUI::ToolbarButton.new('Select') {
          puts 'Tool: Select'
          tool = SelectionTool.new( self )
          select_tool( tool )
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'Select_24.png' )
        @toolbar.add_control( button )
        
        # Move
        button = TT::GUI::ToolbarButton.new('Move') {
          puts 'Tool: Move'
          tool = MoveTool.new( self )
          select_tool( tool )
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'Move_24.png' )
        @toolbar.add_control( button )
        
        # Add QuadPatch
        button = TT::GUI::ToolbarButton.new('Add QuadPatch') {
          puts 'Add QuadPatch'
          PLUGIN.add_quadpatch
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'QuadPatch_24.png' )
        @toolbar.add_control( button )
        
        # Add TriPatch
        button = TT::GUI::ToolbarButton.new('Add TriPatch') {
          puts 'Add TriPatch'
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
          puts "Axis: #{value}"
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
      # Normally, closing a group/component appears in the undo stack.
      # But when this method is used in SU8-M1 and older the action does not
      # appear in the stack - and when you then trigger and undo after using
      # this method all the modified geometry is offset.
      if valid_context?
        TT.debug( '> Closing active context' )
        view.model.close_active
      end
    end
    
  end # class BezierSurfaceEditor
  
end # module TT::Plugins::BezierSurfaceTools