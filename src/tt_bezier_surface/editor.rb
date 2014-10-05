#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # Manages the editing environment for bezier patches.
  #
  # The class is a Tool class, used as the root for the editing tools. This
  # class must be activated first - then the sub-tools are pushed into the
  # stack.
  #
  # Keep this class to managing the editing environment and general UI.
  #
  # @since 1.0.0
  class BezierSurfaceEditor

    # @since 1.0.0
    attr_reader( :model, :surface, :selection, :draw_cache )

    # @since 1.0.0
    def initialize( model )
      # References the context the editor works in when active.
      @model = model
      @selection = Selection.new( self )
      @surface = nil

      # State of the session.
      @active = false

      # References the currently active sub-tool on the stack.
      @active_tool = nil

      # Observers
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
      Console.log( 'BezierSurfaceEditor.edit' )
      # Don't activate a new session while there is one already active.
      if @active
        Console.log( '> Already active edit session!' )
        return false
      end
      @surface = BezierSurface.load( instance )
      if @surface
        # Clear native selection for less visual distraction and avoid
        # tools performing actions on the selection. (Such as the Delete key.)
        @model.selection.clear
        # Activate Bezier Surface editing mode.
        @model.select_tool( self )
        # Start observing the surface for changes.
        @surface.clear_observers! # Just to be safe.
        @surface.add_observer( BST_SurfaceObserver.factory )
        # Activate sub-tool.
        default_tool = SelectionTool.new( self )
        select_tool( default_tool )
      else
        # Invalid instance or incompatible version
        UI.beep
        puts 'Invalid Bezier Surface or incompatible version.'
        model.close_active
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

      m = menu.add_item( 'Select All' ) {
        @selection.add( @surface.manipulable_entities )
      }
      menu.set_validation_proc( m ) { MF_ENABLED | MF_UNCHECKED }

      m = menu.add_item( 'Select None' ) {
        @selection.clear
      }
      menu.set_validation_proc( m ) { MF_ENABLED | MF_UNCHECKED }

      m = menu.add_item( 'Invert Selection' ) {
        @selection.toggle( @surface.manipulable_entities )
      }
      menu.set_validation_proc( m ) { MF_ENABLED | MF_UNCHECKED }

      menu.add_separator

      submenu = menu.add_submenu( 'Manipulate' )

        m = submenu.add_item( 'Vertices' ) { puts 'Vertices' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_CHECKED }

        m = submenu.add_item( 'Handles' ) { puts 'Handles' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_UNCHECKED }

        m = submenu.add_item( 'Edges' ) { puts 'Patches' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_CHECKED }

        m = submenu.add_item( 'Patches' ) { puts 'Patches' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_CHECKED }


      submenu = menu.add_submenu( 'Display' )

        m = submenu.add_item( 'Automatic Interior' ) { puts 'n01' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_CHECKED }

        m = submenu.add_item( 'Interior Grid' ) { puts 'n02' }
        submenu.set_validation_proc( m ) { MF_GRAYED | MF_CHECKED }


      menu.add_separator

      m = menu.add_item( Commands.toggle_properties )


      menu.add_separator

      m = menu.add_item( 'Close Instance' ) { end_session() }
      menu.set_validation_proc( m ) { MF_ENABLED | MF_UNCHECKED }

      menu
    end

    # Activates a bezier editing tool - pushing it into SketchUp's tool stack
    # after ending the existing one.
    #
    # @param [Sketchup::Tool] tool
    #
    # @return [Boolean]
    # @since 1.0.0
    def select_tool( tool )
      Console.log( 'BezierSurfaceEditor.select_tool' )
      tools = @model.tools
      # (i) Some times other tools, for instance viewport tools, push other
      #     tools into the stack. This should be accounted for so we get a
      #     correctly working tool stack.
      #
      # (i) Pop all tools until we have a RubyTool. This is incase one of the
      #     native camera tools had been activated during the session. They
      #     push themselves into the stack.
      #
      # (i) If another RubyTool pushed itself into the stack then this won't
      #     work properly. But it's an edge case which hopefully doesn't need
      #     to be addressed. At least it's considered low priority for now.
      until tools.active_tool_id == 0 || tools.active_tool_id >= 50000
        # tools.active_tool_id might be zero if the entire tool stack has been
        # popped. This is catched just in case to prevent infinite loop. But
        # it should not happen.
        #
        # RubyTools seem to have ids over 50000. Not sure if it's a future safe
        # assumption to make, but active_tool_name is bugged in older SketchUp
        # versions - where the first four letters are trunkated. Which makes it
        # impossible to distinquish it from other tools.
        #
        # (?) Maybe BezierSurface require SketchUp versions that has this fixed
        #     and it is no problem.
        tools.pop_tool
      end
      # Catch tools.active_tool_id == 0 - in case unexpected oddites.
      if tools.active_tool_id == 0
        # This would mean something wrong has happened. At any time during
        # editing, the BezierSurfaceEditor Tool should be present and active.
        # If the stack is empty it means it's been removed and no sub-tools
        # should be pushed into the stack.
        #
        # (?) Alert user about error? Raise exception?
        Console.log( '> Error! Tool stack empty.' )
        return false
      end
      # Pop the current Bezier Surface tool. (At least it should be unless
      # some other plugin pushed a tool into the stack.)
      if @active_tool
        Console.log( '> Pop active tool...' )
        tools.pop_tool
      end
      # Push the new one into the stack in place of the old one.
      Console.log( '> Push new tool...' )
      @active_tool = tool
      tools.push_tool( tool )
    end

    # Ends the active editing session. Called when the bezier surface instance
    # is closed or when the user activates another tool.
    #
    # When the user activates another tool the open bezier instance is closed.
    #
    # @return [Boolean]
    # @since 1.0.0
    def end_session
      Console.log( 'BezierSurfaceEditor.end_session' )
      if @active
        Console.log( '> Ending active tool...' )
        # Instead of popping all tools - just activate the Select tool. Which
        # will deactivate this BezierSurfaceEditor tool and end this session.
        # Trying to get back to the tool used before this one leads to too many
        # potential problems. And the editor isn't pushed into the tool stack
        # anyway - as it would make no sense to run it on top of another tool.
        @model.select_tool( nil )
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

    # Changes the subdivision of the active surface and commits it.
    #
    # @param [Integer] subdivs
    #
    # @return [Boolean]
    # @since 1.0.0
    def change_subdivisions( subdivs )
      # (!) Move to BezierSurface ?
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

    # Updates the current selection with the given entities based on the flags
    # from the mouse event.
    #
    # @param [Array<BezierEntity>] entities
    # @param [Integer] flags Key flags from mouse events.
    #
    # @return [Selection]
    # @since 1.0.0
    def update_selection( entities, key_flags )
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl  = key_flags & COPY_MODIFIER_MASK      == COPY_MODIFIER_MASK
      key_shift = key_flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK

      # Update selection.
      if key_ctrl && key_shift
        @selection.remove( entities )
      elsif key_ctrl
        @selection.add( entities )
      elsif key_shift
        @selection.toggle( entities )
      else
        @selection.clear
        @selection.add( entities )
      end

      @selection
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
      Console.log( 'BezierSurfaceEditor.undo_redo' )
      if valid_context?
        @surface.reload
        invalid_entities = @selection.select { |entity| entity.deleted? }
        # (i) Because BezierSurface.reload doesn't reuse existing entities,
        #     the entities in the current selection is invalid. The whole
        #     selection is therefor cleared.
        #@selection.remove( invalid_entities )
        @selection.clear
        # (i) SelectionObserver doesn't refresh the viewport unless the
        #     selection changed. Which it often doesn't when you undo/redo.
        refresh_viewport() if invalid_entities.empty?
      else
        Console.log( '> Invalid Context' )
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
          :pref_key => "#{PLUGIN_ID}_Toolbar",
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
          Console.log 'Tool: Select'
          tool = SelectionTool.new( self )
          select_tool( tool )
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'Select_24.png' )
        @toolbar.add_control( button )

        # Move
        button = TT::GUI::ToolbarButton.new('Move') {
          Console.log 'Tool: Move'
          tool = MoveTool.new( self )
          select_tool( tool )
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'Move_24.png' )
        @toolbar.add_control( button )

        # Add QuadPatch
        button = TT::GUI::ToolbarButton.new('Add QuadPatch') {
          Console.log 'Add QuadPatch'
          Operations.add_quadpatch
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'QuadPatch_24.png' )
        @toolbar.add_control( button )

        # Add TriPatch
        button = TT::GUI::ToolbarButton.new('Add TriPatch') {
          Console.log 'Add TriPatch'
          #PLUGIN.add_tripatch # (!)
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'TriPatch_24.png' )
        @toolbar.add_control( button )

        # Merge
        button = TT::GUI::ToolbarButton.new('Merge') {
          Console.log 'Tool: Merge'
          tool = MergeTool.new( self )
          select_tool( tool )
          TT::SketchUp.activate_main_window
        }
        button.icon = File.join( PATH_ICONS, 'Merge_24.png' )
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
        list.value = 'Local'
        list.add_event_handler( :change ) { |control, value|
          Console.log "Axis: #{value}"
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

    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#activate
    #
    # @since 1.0.0
    def activate
      Console.log( 'BezierSurfaceEditor.activate' )
      @active = true
      @active_tool = nil
      @selection.clear

      # UI
      show_toolbar()
    end

    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#deactivate
    #
    # @since 1.0.0
    def deactivate(view)
      Console.log( 'BezierSurfaceEditor.deactivate' )
      @active = false
      @active_tool = nil

      close_toolbar()

      # (!) SketchUp bug!
      #     Sketchup.close_active
      #     Normally, closing a group/component appears in the undo stack.
      #     But when close_active is used in SU8-M1 and older the action does
      #     not appear in the stack - so when you then trigger undo/redo after
      #     using this method all the modified geometry is offset.
      if valid_context?
        Console.log( '> Closing active context' )
        view.model.close_active
      end

      # Clean up any observers used during the editing session.
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
