#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  class MoveTool
    
    def initialize( editor )
      @editor = editor
      @surface = editor.surface
      
      @ip_start = Sketchup::InputPoint.new			
			@ip_mouse = Sketchup::InputPoint.new
      
      @preview = false
      
      @select_ctrl = false
      @select_shift = false
    end
    
    def enableVCB?
      true
    end
    
    def update_ui
      @editor.refresh_ui
      if @editor.selection.empty?
        Sketchup.status_text = 'Click a control point and hold down left mouse button to move it.'
      else
        Sketchup.status_text = 'Pick first point.'
      end
      Sketchup.vcb_label = 'Distance'
      Sketchup.vcb_value = 0
    end
    
    def activate
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
      #@editor.change_subdivisions( text.to_i )
      update_ui()
    end
    
    def onCancel(reason, view)
      TT.debug( 'onCancel' )
      case reason
      when 0 # ESC
        TT.debug( '> ESC' )
        @ip_start.clear			
        @ip_mouse.clear
        @start_over_vertex = false
        #@state = S_NORMAL
        #@surface.update( @editor.model.edit_transform )
        view.invalidate
      when 1 # Reactivate Tool
        TT.debug( '> Reactivate' )
      when 2 # Undo
        TT.debug( '> Undo' )
        #@surface.reload
        @ip_start.clear			
        @ip_mouse.clear
        @start_over_vertex = false
        #@state = S_NORMAL
        view.invalidate
        #@surface.update( @editor.model.edit_transform )
      end
    end
    
    def onMouseMove(flags, x, y, view)
      @mouse_over_vertex = @surface.pick_control_points(x, y, view)
      @mouse_over_vertex = false if @mouse_over_vertex.empty?
      if @mouse_over_vertex
        t = view.model.edit_transform
        pt = @mouse_over_vertex[0].position.transform(t)
        @ip_mouse = Sketchup::InputPoint.new( pt )
      else
        if @ip_start.valid?
          @ip_mouse.pick( view, x, y, @ip_start )
        else
          @ip_mouse.pick( view, x, y )
        end
      end
      
      if flags & MK_LBUTTON == MK_LBUTTON
        #@state = S_DRAG
      end
      view.invalidate
    end
    
    def onLButtonDown(flags, x, y, view)
      @ip_start.copy!( @ip_mouse )
      @start_over_vertex = @mouse_over_vertex
    end
    
    def onLButtonUp(flags, x, y, view)
      TT.debug 'MoveTool.onLButtonUp'
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      
      if @ip_start.valid? && @ip_mouse.valid?
        pt_start = @ip_start.position
        pt_end = @ip_mouse.position
        offset_vector = pt_start.vector_to( pt_end )
        if offset_vector.valid?
          # Transform selected vertices, or if there is no selection move the
          # vertices the user initially clicked on.
          # (!) Update
          if @editor.selection.empty?
            vertices = ( @start_over_vertex ) ? @start_over_vertex : []
          else
            vertices = @editor.selection.related_control_points
          end

          @surface.transform_entities( vertices, offset_vector )
          
          @editor.model.start_operation( 'Move Bezier Entities' )
          @surface.update
          @editor.model.commit_operation
        end
      end
      
      # Reset variables for next mouse action.
      @ip_start.clear			
			@ip_mouse.clear
      @start_over_vertex = false
      #@state = S_NORMAL
      view.invalidate
    end
    
    def onKeyDown(key, repeat, flags, view)
      @select_ctrl  = true if key == COPY_MODIFIER_KEY
      @select_shift = true if key == CONSTRAIN_MODIFIER_KEY
      
      if @select_shift
        if @ip_mouse.valid? && @ip_start.valid?
          #view.lock_inference( @ip_start, @ip_mouse )
          view.lock_inference( @ip_mouse, @ip_start )
        end
        view.invalidate
      end
      
      #onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    def onKeyUp(key, repeat, flags, view)
      @select_ctrl  = false if key == COPY_MODIFIER_KEY
      @select_shift = false if key == CONSTRAIN_MODIFIER_KEY
      view.lock_inference
      view.invalidate
      #onSetCursor()
      false
    end
    
    def draw(view)
      #@surface.draw_internal_grid( view, @preview )
      #@surface.draw_edges( view, @surface.edges )
      #@surface.draw_control_grid( view )
      #@surface.draw_control_points( view, @editor.selection.to_a )
      @editor.draw_cache.render
      
      if @ip_mouse.valid? && @ip_start.valid? #&& !view.inference_locked?
        pt1 = @ip_start.position
        pt2 = @ip_mouse.position
        view.line_width = ( view.inference_locked? ) ? 2 : 1
        view.line_width = 1
        view.line_stipple = '-'
        view.set_color_from_line( pt1, pt2 )
        view.draw( GL_LINES, pt1, pt2 )
      end
      
      view.line_width = 2
        
      #view.tooltip = "Valid: #{@ip_mouse.valid?}\nDisplay: #{@ip_mouse.display?}"
      if @ip_mouse.valid? && @ip_mouse.display?
        view.line_stipple = '.'
        @ip_mouse.draw( view ) 
      elsif @mouse_over_vertex
        view.line_stipple = ''
        view.draw_points( @ip_mouse.position, 7, 3, [0,0,0] )
      end
      
      if @ip_start.valid? && @ip_start.display?
        view.line_stipple = '.'
        @ip_start.draw( view ) 
      elsif @start_over_vertex
        view.line_stipple = ''
        view.draw_points( @ip_start.position, 7, 3, [255,0,0] )
      end
    end
    
    def onSetCursor_disabled
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
    
  end # class VertexSelectionTool

end # module