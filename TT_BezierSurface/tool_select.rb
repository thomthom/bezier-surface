#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  class SelectionTool
    
    STATE_NORMAL  = 0
    STATE_DRAG    = 1
    
    # @since 1.0.0
    def initialize( editor )
      @editor = editor
      @surface = editor.surface
      
      @selection_rectangle = SelectionRectangle.new( @surface )
      @gizmo = nil
      
      # Tool state.
      # Set to STATE_DRAG when a selection box is active.
      @state = STATE_NORMAL
      
      # Used by onSetCursor
      @key_ctrl = false
      @key_shift = false
      @mouse_over_vertex = false
      
      @cursor         = TT::Cursor.get_id( :select )
      @cursor_add     = TT::Cursor.get_id( :select_add )
      @cursor_remove  = TT::Cursor.get_id( :select_remove )
      @cursor_toggle  = TT::Cursor.get_id( :select_toggle )
      
      @cursor_vertex        = TT::Cursor.get_id( :vertex )
      @cursor_vertex_add    = TT::Cursor.get_id( :vertex_add )
      @cursor_vertex_remove = TT::Cursor.get_id( :vertex_remove )
      @cursor_vertex_toggle = TT::Cursor.get_id( :vertex_toggle )
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#getInstructorContentDirectory
    # @see TT::Plugins::BezierSurfaceTools#get_instructor_path
    #
    # @since 1.0.0
    def getInstructorContentDirectory
      real_path = File.join( PLUGIN::PATH, 'InstructorContent', 'Test' )
      adjusted_path = PLUGIN.get_instructor_path( real_path )
      TT::debug( adjusted_path )
      adjusted_path
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#enableVCB?
    #
    # @since 1.0.0
    def enableVCB?
      true
    end
    
    # Updates the statusbar and VCB.
    #
    # @return [Nil]
    # @since 1.0.0
    def update_ui
      Sketchup.status_text = 'Click an entity to select and manipulate it.'
      Sketchup.vcb_label = 'Subdivisions'
      Sketchup.vcb_value = @surface.subdivs
      nil
    end
    
    # Called by BezierEditor when the selection or geometry has updated.
    # The viewport graphics then needs updating.
    #
    # @return [Nil]
    # @since 1.0.0
    def refresh_viewport
      #puts 'SelectTool.refresh_viewport'
      update_gizmo()
      nil
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#activate
    #
    # @since 1.0.0
    def activate    
      init_gizmo()
      update_ui()
      @editor.refresh_viewport
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#deactivate
    #
    # @since 1.0.0
    def deactivate( view )
      view.invalidate
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#resume
    #
    # @since 1.0.0
    def resume( view )
      update_ui()
      @editor.refresh_viewport
      view.invalidate
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#getMenu
    #
    # @since 1.0.0
    def getMenu( menu )
      @editor.context_menu( menu )
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onUserText
    #
    # @since 1.0.0
    def onUserText( text, view )
      subdivs = text.to_i
      if SUBDIVS_RANGE.include?( subdivs )
        @editor.change_subdivisions( subdivs )
      else
        UI.beep
      end
      view.invalidate
      update_ui()
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onMouseMove
    #
    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      # Use view.refresh instead of view.invalidate as the latter doesn't
      # update often enough. View.refresh force the viewport to update.
      #
      # (?) Maybe limit how many refreshes are made for better performance?
      #     http://forums.sketchucation.com/viewtopic.php?f=180&t=37624
      #
      # (i) View.refresh require SketchUp 7.1+
      
      # Handle Gizmo
      if @gizmo.onMouseMove( flags, x, y, view )
        view.tooltip = @gizmo.tooltip
        view.refresh
        return true
      end
      
      # Selection Rectangle is made if left button is pressed.
      if flags & MK_LBUTTON == MK_LBUTTON
        @state = STATE_DRAG
        @selection_rectangle.end = Geom::Point3d.new( x, y, 0 )
        view.refresh
      else
        @state = STATE_NORMAL
        result = @surface.pick_control_points_ex( x, y, view )
        @mouse_over_vertex = !result.empty?
      end
      
      view.invalidate # (!) Temp - need Manipulator.onMouseOut
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onLButtonDown
    #
    # @since 1.0.0
    def onLButtonDown( flags, x, y, view )
      if @gizmo.onLButtonDown( flags, x, y, view )
        view.invalidate
      else
        @selection_rectangle.start = Geom::Point3d.new( x, y, 0 )
      end
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onLButtonUp
    #
    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      # Handle Gizmo
      if @gizmo.onLButtonUp(flags, x, y, view)
        view.invalidate
        return
      end
      
      # Pick entities.
      entities = []
      if @state == STATE_NORMAL
        # Control Points
        picked = @surface.pick_control_points_ex( x, y, view )
        entities.concat( picked )
        # Edges
        if entities.empty?
          picked = @surface.pick_edges( @surface.subdivs, x, y, view )
          entities.concat( picked )
        end
        # Patch
        if entities.empty?
          picked = @surface.pick_patch( x, y, view )
          entities << picked if picked
        end
      else
        s = @surface
        availible = s.vertices + s.manual_interior_points + s.edges + s.patches
        entities = @selection_rectangle.selected_entities( view, availible )
      end
      
      update_selection( entities, flags )
      
      @state = STATE_NORMAL
      @selection_rectangle.reset
      view.invalidate
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onLButtonDoubleClick
    #
    # @since 1.0.0
    def onLButtonDoubleClick( flags, x, y, view )
      # Pick entities.
      patch = @surface.pick_patch( x, y, view )
      return false unless patch
      
      # Add patch and bordering edges.
      entities = patch.edges
      entities << patch
      
      update_selection( entities, flags )
      
      view.invalidate
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyDown
    #
    # @since 1.0.0
    def onKeyDown( key, repeat, flags, view )
      @key_ctrl  = true if key == COPY_MODIFIER_KEY
      @key_shift = true if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyUp
    #
    # @since 1.0.0
    def onKeyUp( key, repeat, flags, view )
      @key_ctrl  = false if key == COPY_MODIFIER_KEY
      @key_shift = false if key == CONSTRAIN_MODIFIER_KEY
      # Detect Delete key - VK_DELETE
      # (!) VK_DELETE does not trigger onKeyDown under Windows. Therefor the
      #     key must be detected on key up. This deviate from SketchUp's native
      #     behaviour.
      #
      #   * When only Delete is pressed, it triggers only onKeyUp.
      #   * When Shift+Delete is pressed, it only onKeyUp.
      #   * When Ctrl+Delete is pressed, it triggers both onKeyDown and onKeyUp.
      #   * When Alt+Delete is pressed, it triggers both onKeyDown and onKeyUp.
      #
      # (?) Should this belong to Editor - as it should work for all tools?
      if key == VK_DELETE && !@editor.selection.empty?
        view.model.start_operation( 'Erase' )
        @surface.erase_entities( @editor.selection )
        view.model.commit_operation
      end
      onSetCursor()
      false
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#draw
    #
    # @since 1.0.0
    def draw( view )
      # <debug>
      t_start = Time.now
      # </debug>
      
      @editor.draw_cache.render
      @selection_rectangle.draw( view )
      @gizmo.draw( view ) unless @editor.selection.empty?
      
      # <debug>
      elapsed = Time.now - t_start
      view.draw_text( [20,20,0], sprintf( 'Last Frame: %.4fs', elapsed ) )
      
      view.draw_text( [20,50,0], sprintf( 'Last Refresh Time: %.4fs', view.last_refresh_time ) )
      view.draw_text( [20,65,0], sprintf( 'Average Refresh Time: %.4fs', view.average_refresh_time ) )
      # </debug>
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onSetCursor
    #
    # @since 1.0.0
    def onSetCursor
      if @key_ctrl && @key_shift
        cursor = (@mouse_over_vertex) ? @cursor_vertex_remove : @cursor_remove
      elsif @key_ctrl
        cursor = (@mouse_over_vertex) ? @cursor_vertex_add : @cursor_add
      elsif @key_shift
        cursor = (@mouse_over_vertex) ? @cursor_vertex_toggle : @cursor_toggle
      else
        cursor = (@mouse_over_vertex) ? @cursor_vertex : @cursor
      end
      UI.set_cursor( cursor )
    end
    
    private
    
    # @return [Nil]
    # @since 1.0.0
    def init_gizmo
      tr = @editor.model.edit_transform
 
      selection_points = @editor.selection.map { |cpt| cpt.position }
      pt = TT::Geom3d.average_point( selection_points ).transform( tr )
      xaxis = X_AXIS.transform( tr )
      yaxis = Y_AXIS.transform( tr )
      zaxis = Z_AXIS.transform( tr )
      
      @gizmo = TT::Gizmo::Manipulator.new( pt, xaxis, yaxis, zaxis )
      
      # (!) Return name of operation in block
      @gizmo.on_transform_start {
        @editor.model.start_operation( 'Edit Control Points' )
        @surface.preview
      }
      
      @gizmo.on_transform { |t_increment, t_total|
        entities = @editor.selection.related_control_points
        @surface.transform_entities( t_increment, entities )
      }
      
      @gizmo.on_transform_end {
        @surface.update
        @editor.model.commit_operation
        update_ui()
      }
      
      nil
    end
    
    # Called after geometry and selection change.
    #
    # @return [Boolean]
    # @since 1.0.0
    def update_gizmo
      return false if @gizmo.active?
      # Update Gizmo
      tr = @editor.model.edit_transform
      control_points = @editor.selection.to_control_points
      positions = control_points.map { |cpt| cpt.position }
      average = TT::Geom3d.average_point( positions )
      @gizmo.origin = average.transform( tr )
      true
    end
    
    # Updates the current selection with the given entities based on the flags
    # from the mouse event.
    #
    # @return [Selection]
    # @since 1.0.0
    def update_selection( entities, flags )
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      
      # Update selection.
      if key_ctrl && key_shift
        @editor.selection.remove( entities )
      elsif key_ctrl
        @editor.selection.add( entities )
      elsif key_shift
        @editor.selection.toggle( entities )
      else
        @editor.selection.clear
        @editor.selection.add( entities )
      end
      
      @editor.selection
    end
    
  end # class SelectionTool

end # module