#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  class MoveTool
    
    # @since 1.0.0
    def initialize( editor )
      @editor = editor
      @surface = editor.surface
      
      @ip_start = Sketchup::InputPoint.new			
			@ip_mouse = Sketchup::InputPoint.new
      
      # Used by onSetCursor
      @key_ctrl = false
      @key_shift = false
      
      # (!) Display vertex cursor only when mouse is over a control point
      #     and the selection is empty.
      @cursor         = TT::Cursor.get_id( :move )
      @cursor_vertex  = TT::Cursor.get_id( :vertex )
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
      if @editor.selection.empty?
        Sketchup.status_text = 'Click a control point and hold down left mouse button to move it.'
      else
        Sketchup.status_text = 'Pick first point.'
      end
      Sketchup.vcb_label = 'Distance'
      Sketchup.vcb_value = 0
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#activate
    #
    # @since 1.0.0
    def activate
      update_ui()
      @editor.refresh_viewport
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#deactivate
    #
    # @since 1.0.0
    def deactivate(view)
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
    
    def onUserText( text, view )
      # (!) Adjust last move operation.
      update_ui()
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onCancel
    #
    # @since 1.0.0
    def onCancel( reason, view )
      TT.debug( 'onCancel' )
      case reason
      when 0 # ESC
        TT.debug( '> ESC' )
        @ip_start.clear			
        @ip_mouse.clear
        @start_over_vertex = false
        # (!) Abort operation. After mouse down triggers start_operation.
        view.invalidate
      when 1 # Reactivate Tool
        TT.debug( '> Reactivate' )
        # (?) Same as ESC?
      when 2 # Undo
        TT.debug( '> Undo' )
        @ip_start.clear			
        @ip_mouse.clear
        @start_over_vertex = false
        view.invalidate
      end
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onMouseMove
    #
    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      # (!) Pick separate entities.
      # * Pick mouse snapping entity
      # * Pick mouse-select entity - used when the selection is empty.
      @mouse_over_vertex = @surface.pick_control_points_ex( x, y, view )
      @mouse_over_vertex = false if @mouse_over_vertex.empty?
      if @mouse_over_vertex
        tr = view.model.edit_transform
        pt = @mouse_over_vertex[0].position.transform( tr )
        @ip_mouse = Sketchup::InputPoint.new( pt )
      else
        if @ip_start.valid?
          @ip_mouse.pick( view, x, y, @ip_start )
        else
          @ip_mouse.pick( view, x, y )
        end
      end
      
      if flags & MK_LBUTTON == MK_LBUTTON
        # (!) Left mouse button drag
        # * First Event:
        #   * preview mesh
        #   * start_transformation
        # * Afterwards
        # * update preview mesh
      end
      view.invalidate
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onLButtonDown
    #
    # @since 1.0.0
    def onLButtonDown( flags, x, y, view )
      @ip_start.copy!( @ip_mouse )
      @start_over_vertex = @mouse_over_vertex
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onLButtonUp
    #
    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
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
          if @editor.selection.empty?
            vertices = ( @start_over_vertex ) ? @start_over_vertex : []
          else
            vertices = @editor.selection.related_control_points
          end
          # (!) Move Selection.related_control_points to separate method.
          # Get related control points from picked entities.
          
          tr = Geom::Transformation.new( offset_vector )
          
          @editor.model.start_operation( 'Move Bezier Entities' )
          @surface.transform_entities( tr, vertices )
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
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyDown
    #
    # @since 1.0.0
    def onKeyDown( key, repeat, flags, view )
      @key_ctrl  = true if key == COPY_MODIFIER_KEY
      @key_shift = true if key == CONSTRAIN_MODIFIER_KEY
      
      if @key_shift
        if @ip_mouse.valid? && @ip_start.valid?
          view.lock_inference( @ip_mouse, @ip_start )
        end
        view.invalidate
      end
      
      onSetCursor()
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onKeyUp
    #
    # @since 1.0.0
    def onKeyUp( key, repeat, flags, view )
      @key_ctrl  = false if key == COPY_MODIFIER_KEY
      @key_shift = false if key == CONSTRAIN_MODIFIER_KEY
      view.lock_inference
      view.invalidate
      onSetCursor()
      false
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#draw
    #
    # @since 1.0.0
    def draw( view )
      @editor.draw_cache.render
      
      # Move indication.
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
      
      # Inference from mouse position.
      #view.tooltip = "Valid: #{@ip_mouse.valid?}\nDisplay: #{@ip_mouse.display?}"
      if @ip_mouse.valid? && @ip_mouse.display?
        view.line_stipple = '.'
        @ip_mouse.draw( view ) 
      elsif @mouse_over_vertex
        view.line_stipple = ''
        view.draw_points( @ip_mouse.position, 7, 3, [0,0,0] )
      end
      
      # Inference from move origin.
      if @ip_start.valid? && @ip_start.display?
        view.line_stipple = '.'
        @ip_start.draw( view ) 
      elsif @start_over_vertex
        view.line_stipple = ''
        view.draw_points( @ip_start.position, 7, 3, [255,0,0] )
      end
    end
    
    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onSetCursor
    #
    # @since 1.0.0
    def onSetCursor
      cursor = (@mouse_over_vertex) ? @cursor_vertex : @cursor
      UI.set_cursor( cursor )
    end
    
  end # class VertexSelectionTool

end # module