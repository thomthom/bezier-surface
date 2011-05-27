#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  class SelectionTool
    
    STATE_NORMAL  = 0
    STATE_DRAG    = 1
    
    def initialize( editor )
      @editor = editor
      @surface = editor.surface
      
      @selection_rectangle = SelectionRectangle.new( @surface )
      
      @preview = false # Non-false when mesh is previewed
      
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

    def enableVCB?
      true
    end
    
    # @since 1.0.0
    def update_ui
      update_viewport_cache()
      Sketchup.status_text = 'Click an entity to select and manipulate it.'
      Sketchup.vcb_label = 'Subdivisions'
      Sketchup.vcb_value = @surface.subdivs
    end
    
    def activate    
      @editor.selection.clear
      init_gizmo()
      update_ui()
    end
    
    def deactivate( view )
      view.invalidate
    end
    
    def resume( view )
      view.invalidate
      update_ui()
    end
    
    def getMenu( menu )
      @editor.context_menu( menu )
    end
    
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
    
    def onMouseMove( flags, x, y, view )
      # Handle Gizmo
      if @gizmo.onMouseMove( flags, x, y, view )
        view.invalidate
        return true
      end
      
      # Selection Rectangle is made if left button is pressed.
      if flags & MK_LBUTTON == MK_LBUTTON
        @state = STATE_DRAG
        @selection_rectangle.end = Geom::Point3d.new( x, y, 0 )
        view.invalidate
      else
        @state = STATE_NORMAL
        result = @surface.pick_control_points_ex( x, y, view )
        @mouse_over_vertex = !result.empty?
      end
      
      view.invalidate # (!) Temp - need Manipulator.onMouseOut
    end
    
    def onLButtonDown( flags, x, y, view )
      if @gizmo.onLButtonDown( flags, x, y, view )
        view.invalidate
      else
        @selection_rectangle.start = Geom::Point3d.new( x, y, 0 )
      end
    end
    
    def onLButtonUp( flags, x, y, view )
      # Handle Gizmo
      if @gizmo.onLButtonUp(flags, x, y, view)
        view.invalidate
        return
      end
      
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      
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
      update_viewport_cache()
      
      @editor.update_properties
      
      @state = STATE_NORMAL
      @selection_rectangle.reset
      view.invalidate
    end
    
    def onKeyDown(key, repeat, flags, view)
      @key_ctrl  = true if key == COPY_MODIFIER_KEY
      @key_shift = true if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    def onKeyUp(key, repeat, flags, view)
      @key_ctrl  = false if key == COPY_MODIFIER_KEY
      @key_shift = false if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor()
      false
    end
    
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
    
    def init_gizmo
      tr = @editor.model.edit_transform
 
      selection_points = @editor.selection.map { |cpt| cpt.position }
      pt = TT::Geom3d.average_point( selection_points ).transform( tr )
      xaxis = X_AXIS.transform( tr )
      yaxis = Y_AXIS.transform( tr )
      zaxis = Z_AXIS.transform( tr )
      
      @gizmo = TT::Gizmo::Manipulator.new( pt, xaxis, yaxis, zaxis )
      
      @gizmo.on_transform_start {
        @editor.model.start_operation( 'Edit Control Points' )
        @preview = 4 # Subdivisions
        @surface.preview( @editor.model.edit_transform, @preview )
        # Cache the vertices for use in the on_transform event.
        @vertex_cache = @surface.mesh_vertices( @preview, @editor.model.edit_transform )
        @editor.refresh_ui
      }
      
      @gizmo.on_transform { |t_increment, t_total|
        # <debug>
        t_1 = Time.now
        # </debug>
      
        # (!) Replace with @surface.transform_entities
        tr = @editor.local_transformation( t_increment )
        for control_point in @editor.selection.related_control_points
          control_point.position.transform!( tr )
        end
        @surface.refresh_automatic_patches
        positions = @surface.mesh_points( @preview, @editor.model.edit_transform ) # (!) Slow
        @surface.set_vertex_positions( @vertex_cache, positions )
        @editor.refresh_ui # (!) Slow
        
        # <debug>
        t_end = Time.now
        TT.debug '@gizmo.on_transform'
        TT.debug "> Total: #{t_end - t_1}"
        # </debug>
      }
      
      @gizmo.on_transform_end {
        @surface.update( @editor.model.edit_transform )
        @editor.model.commit_operation
        @preview = false
        update_ui()
      }
    end
    
    # @since 1.0.0
    def update_viewport_cache
      @editor.refresh_ui
      
      # Update Gizmo
      tr = @editor.model.edit_transform
      control_points = @editor.selection.to_control_points
      positions = control_points.map { |cpt| cpt.position }
      average = TT::Geom3d.average_point( positions )
      @gizmo.origin = average.transform( tr )
    end
    
  end # class SelectionTool

end # module