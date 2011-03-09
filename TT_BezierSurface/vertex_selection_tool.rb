#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::BPatch
  
  class VertexSelectionTool
    
    S_NORMAL  = 0
    S_DRAG    = 1
    
    def initialize( editor )
      @editor = editor
      @surface = editor.surface
      
      @ip_start = Sketchup::InputPoint.new			
			@ip_mouse = Sketchup::InputPoint.new
      
      # Used for Rectangle Selection
      @screen_start = nil
      @screen_mouse = nil
      
      # Tool state.
      # Set to S_DRAG when a selection box is active.
      @state = S_NORMAL
      
      @preview = false
      
      @mouse_over_vertex = false
      @select_ctrl = false
      @select_shift = false
      
      @cursor         = TT::Cursor.get_id(:select)
      @cursor_add     = TT::Cursor.get_id(:select_add)
      @cursor_remove  = TT::Cursor.get_id(:select_remove)
      @cursor_toggle  = TT::Cursor.get_id(:select_toggle)
      
      @cursor_vertex        = TT::Cursor.get_id(:vertex)
      @cursor_vertex_add    = TT::Cursor.get_id(:vertex_add)
      @cursor_vertex_remove = TT::Cursor.get_id(:vertex_remove)
      @cursor_vertex_toggle = TT::Cursor.get_id(:vertex_toggle)
    end
    
    def enableVCB?
      true
    end
    
    def update_ui
      Sketchup.status_text = 'Click a control point to select it.'
      Sketchup.vcb_label = 'Subdivisions'
      Sketchup.vcb_value = @surface.subdivs
    end
    
    # On transformation start:
    # * Generate low poly mesh
    # * Collect vertices
    # * Map vertices to Patch points
    # On transformation - move vertices
    # On transformation end:
    # * Regenerate full mesh
    # * Update UI
    def activate
      t = @editor.model.edit_transform
 
      pt = TT::Geom3d.average_point( @editor.selection ).transform( t )
      xaxis = X_AXIS.transform( t )
      yaxis = Y_AXIS.transform( t )
      zaxis = Z_AXIS.transform( t )
      
      @gizmo = TT::Gizmo::Manipulator.new( pt, xaxis, yaxis, zaxis )
      @gizmo.on_transform_start {
        @editor.model.start_operation('Edit Control Points')
        @preview = 4
        @surface.preview( @editor.model.edit_transform, @preview )
        # Cache the vertices for use in the on_transform event.
        @vertex_cache = @surface.mesh_vertices( @preview, @editor.model.edit_transform )
      }
      @gizmo.on_transform { |t_step, t_total|
        et = @editor.model.edit_transform
        local_transform = (et.inverse * t_step) * et
        @editor.selection.each { |pt|
          pt.transform!( local_transform )
        }
        positions = @surface.mesh_points( @preview, @editor.model.edit_transform )
        @surface.set_vertex_positions( @vertex_cache, positions )
      }
      @gizmo.on_transform_end {
        @surface.update( @editor.model.edit_transform )
        @editor.model.commit_operation
        @preview = false
        update_ui()
      }
      
      @state = S_NORMAL
      update_ui()
    end
    
    def deactivate(view)
      view.invalidate
    end
    
    def resume(view)
      view.invalidate
      update_ui()
    end
    
    def onUserText(text, view)
      @editor.change_subdivisions( text.to_i )
      update_ui()
    end
    
    def onCancel(reason, view)
      TT.debug( 'onCancel' )
      case reason
      when 0 # ESC
        TT.debug( '> ESC' )
        @ip_start.clear			
        @ip_mouse.clear
        @state = S_NORMAL
        @surface.update( @editor.model.edit_transform )
        # (!) Gizmo.reset
        view.invalidate
      when 1 # Reactivate Tool
        TT.debug( '> Reactivate' )
      when 2 # Undo
        TT.debug( '> Undo' )
        #@surface.reload
        @ip_start.clear			
        @ip_mouse.clear
        @state = S_NORMAL
        view.invalidate
      end
    end
    
    def onMouseMove(flags, x, y, view)
      @mouse_over_vertex = false
      if @gizmo.onMouseMove(flags, x, y, view)
        #view.invalidate
      else
        @ip_mouse.pick(view, x, y)
        @screen_mouse = Geom::Point3d.new( x, y, 0 )
        if flags & MK_LBUTTON == MK_LBUTTON
          @state = S_DRAG
          #view.invalidate
        else
          @mouse_over_vertex = @surface.pick_control_points(x, y, view)
          @mouse_over_vertex = false if @mouse_over_vertex.empty?
        end
      end
      view.invalidate
    end
    
    def onLButtonDown(flags, x, y, view)
      #puts 'onLButtonDown'
      if @gizmo.onLButtonDown(flags, x, y, view)
        #puts '> Gizmo'
        view.invalidate
      else
        #puts '> Selection'
        @ip_start.copy!(@ip_mouse)
        @screen_start = Geom::Point3d.new( x, y, 0 )
      end
    end
    
    # (!) Optimize and clean up code!
    def onLButtonUp(flags, x, y, view)
      #puts 'onLButtonDown'
      if @gizmo.onLButtonUp(flags, x, y, view)
        #puts '> Gizmo'
        view.invalidate
        return
      end
      
      #puts '> Selection'
      
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      
      # Get set of control points the user has interacted with either by
      # clicking them or a selection box.
      t = view.model.edit_transform
      points = []
      case @state
      when S_NORMAL
        points = @surface.pick_control_points( x, y, view )
      when S_DRAG
        if @ip_start.valid? && @ip_mouse.valid?
          TT.debug( '> Rectangle Selection' )
          polygon = selection_polygon()
          points = @surface.control_points.select { |pt|
            pt2d = view.screen_coords( pt.transform(t) )
            Geom.point_in_polygon_2D( pt2d, polygon, true )
          }
        end
      end # case
      
      # Update selection
      if key_ctrl && key_shift
        @editor.selection.remove( points )
      elsif key_ctrl
        @editor.selection.add( points )
      elsif key_shift
        @editor.selection.toggle( points )
      else
        @editor.selection.clear
        @editor.selection.add( points )
      end
      
      # Update Gizmo
      average = TT::Geom3d.average_point( @editor.selection )
      @gizmo.origin = average.transform(t)
      
      # Reset variables for next mouse action.
      @ip_start.clear			
			@ip_mouse.clear
      @state = S_NORMAL
      view.invalidate
    end
    
    def onKeyDown(key, repeat, flags, view)
      @select_ctrl  = true if key == COPY_MODIFIER_KEY
      @select_shift = true if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    def onKeyUp(key, repeat, flags, view)
      @select_ctrl  = false if key == COPY_MODIFIER_KEY
      @select_shift = false if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor()
      false
    end
    
    def draw(view)
      @editor.draw( view, @preview )
      
      case @state
      when S_NORMAL
        # ...
      when S_DRAG
        view.line_stipple = ''
        view.line_width = 2
        view.drawing_color = CLR_SELECTION
        view.draw2d( GL_LINE_LOOP, selection_polygon() )
      end # case
      
      @gizmo.draw( view ) unless @editor.selection.empty?
    end
    
    def onSetCursor
      if @select_ctrl && @select_shift
        cursor = (@mouse_over_vertex) ? @cursor_vertex_remove : @cursor_remove
      elsif @select_ctrl
        cursor = (@mouse_over_vertex) ? @cursor_vertex_add : @cursor_add
      elsif @select_shift
        cursor = (@mouse_over_vertex) ? @cursor_vertex_toggle : @cursor_toggle
      else
        cursor = (@mouse_over_vertex) ? @cursor_vertex : @cursor
      end
      UI.set_cursor( cursor )
    end
    
    private
    
    def selection_polygon
      # Generate Selection Polygon
      pt1 = @screen_start
      pt3 = @screen_mouse
      pt2 = @screen_start.clone
      pt2.x = pt3.x
      pt4 = @screen_start.clone
      pt4.y = pt3.y
      [ pt1, pt2, pt3, pt4 ]
    end
    
  end # class VertexSelectionTool

end # module