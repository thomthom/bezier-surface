#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  class MoveOperator < Operator
    
    # @since 1.0.0
    def initialize( *args )
      super

      @cache = nil
      @vector = nil
      @length = nil

      @ip_start = Sketchup::InputPoint.new      
      @ip_mouse = Sketchup::InputPoint.new   
      @entity_under_mouse = nil

      @cursor         = TT::Cursor.get_id( :move )
      @cursor_vertex  = TT::Cursor.get_id( :vertex )
    end
    
    # @since 1.0.0
    def enableVCB?
      true
    end
    
    # @since 1.0.0
    def activate
      update_ui()
    end

    # @since 1.0.0
    def onUserText( text, view )
      @length = text.to_l
      if @cache && @vector
        tr = Geom::Transformation.new( translation_vector() )
        @cache.transform_entities( tr )
        reset()
      end
    rescue
      UI.beep
      view.tooltip = "Invalid length entered."
    ensure
      update_ui()
      true
    end
    
    # @since 1.0.0
    def onCancel( reason, view )
      TT.debug( 'onCancel' )
      view.model.abort_operation
      case reason
      when CANCEL_ESC
        TT.debug( '> ESC' )
        reset_all()
      when CANCEL_REACTIVATE
        TT.debug( '> Reactivate' )
      when CANCEL_UNDO
        TT.debug( '> Undo' )
        reset_all()
      end
      view.invalidate
      update_ui()
      true
    end
    
    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      # Find entity under the mouse cursor. This is used for snapping and for
      # quick-select when no entity is pre-selected.
      @entity_under_mouse = @surface.pick_editable_point( x, y, view )

      # Pick InputPoint with snapping to bezier geometry and inference.
      if @entity_under_mouse
        # Snap to BezierEntity geometry.
        tr = view.model.edit_transform
        pt = @entity_under_mouse.position.transform( tr )
        @ip_mouse = Sketchup::InputPoint.new( pt )
      else
        if @ip_start.valid?
          @ip_mouse.pick( view, x, y, @ip_start )
        else
          @ip_mouse.pick( view, x, y )
        end
      end
      view.tooltip = "Mouse: #{@ip_mouse.degrees_of_freedom}\nStart: #{@ip_start.degrees_of_freedom}\nLocked: #{view.inference_locked?.inspect}"

      # Move the entities.
      mouse_down = flags & MK_LBUTTON == MK_LBUTTON
      is_moving = @ip_start.valid? && @ip_mouse.valid?
      if is_moving
        @vector = @ip_start.position.vector_to( @ip_mouse.position )
        @length = @vector.length
      end
      view.tooltip = "mouse_down: #{mouse_down}\nis_moving: #{is_moving}\nvector: #{@vector.inspect}\ncache: #{@cache.inspect}"
      if @cache && @vector && ( mouse_down || is_moving )
        tr = Geom::Transformation.new( translation_vector() )
        @cache.transform_entities( tr, true )
      end

      update_ui()
      #view.invalidate
      view.refresh # (!) Temp? Until better performance.
    end
    
    # @since 1.0.0
    def onLButtonDown( flags, x, y, view )
      super
      unless @ip_start.valid?
        # Move operation start.
        view.model.start_operation( 'Move' )
        @ip_start.copy!( @ip_mouse )
        @quickpick_entity = @entity_under_mouse
        if @quickpick_entity
          entities = [ @quickpick_entity ]
        else
          entities = @editor.selection.related_control_points
        end
        @cache = EntityCache.new( @editor, entities )
        @vector = nil
        @length = nil
      end
      true
    end
    
    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      super
      #puts 'MoveTool.onLButtonUp'
      if @vector
        # Click + Move + Click
        # Mousedown + Move + Mouseup
        vector = translation_vector()
        tr = Geom::Transformation.new( translation_vector() )
        @cache.transform_entities( tr )
        view.model.commit_operation
        reset()
      end
      view.invalidate
      true
    end
    
    # @since 1.0.0
    def onKeyDown( key, repeat, flags, view )
      #puts "MoveOperator.onKeyDown()"
      super
      if @key_shift
        if @ip_mouse.valid? && @ip_start.valid?
          view.lock_inference( @ip_mouse, @ip_start )
        end
        view.invalidate
      end
      view.tooltip = "Mouse: #{@ip_mouse.degrees_of_freedom}\nStart: #{@ip_start.degrees_of_freedom}\nLocked: #{view.inference_locked?.inspect}"
      false
    end
    
    # @since 1.0.0
    def onKeyUp( key, repeat, flags, view )
      #puts "MoveOperator.onKeyUp()"
      super
      view.lock_inference
      view.invalidate
      view.tooltip = "Mouse: #{@ip_mouse.degrees_of_freedom}\nStart: #{@ip_start.degrees_of_freedom}\nLocked: #{view.inference_locked?.inspect}"
      false
    end
    
    # @since 1.0.0
    def draw( view )
      #TT.debug "MoveOperator.draw()"
      @editor.draw_cache.render
      
      # Move direction indication.
      if @ip_mouse.valid? && @ip_start.valid? #&& !view.inference_locked?
        #TT.debug "> Move indication"
        pt1 = @ip_start.position
        pt2 = @ip_mouse.position
        #TT.debug "  > #{pt1}"
        #TT.debug "  > #{pt2}"
        view.line_width = ( view.inference_locked? ) ? 2 : 1
        #view.line_width = 1
        #view.line_stipple = '_'
        view.line_stipple = '-'
        #view.line_stipple = '.'
        view.set_color_from_line( pt1, pt2 )
        view.drawing_color = 'purple'
        unless view.inference_locked? && @ip_mouse.degrees_of_freedom == 0
          view.draw( GL_LINES, pt1, pt2 ) #unless view.inference_locked?
        end
      end
      
      view.line_width = 2
      
      # Inference from mouse position.
      if @ip_mouse.valid? && @ip_mouse.display?
        #TT.debug "> Inference from mouse position (0)"
        #view.line_stipple = '.'
        view.line_stipple = '_'
        @ip_mouse.draw( view ) 
      elsif @entity_under_mouse
        #TT.debug "> Inference from mouse position (1)"
        view.line_stipple = ''
        view.draw_points( @ip_mouse.position, 7, 3, [0,0,0] )
      end
      
      # Inference from move origin.
      if @ip_start.valid? && @ip_start.display?
        #TT.debug "> Inference from move origin (0)"
        #view.line_stipple = '.'
        #view.line_stipple = '-'
        #view.line_stipple = '_'
        #view.line_stipple = ''
        @ip_start.draw( view ) 
      elsif @quickpick_entity
        #TT.debug "> Inference from move origin (1)"
        view.line_stipple = ''
        #view.draw_points( @ip_start.position, 7, 3, [255,0,0] )
        view.draw_points( @ip_start.position, 7, 3, [128,255,0] )
      end
    end
    
    # @since 1.0.0
    def onSetCursor
      cursor = (@entity_under_mouse) ? @cursor_vertex : @cursor
      UI.set_cursor( cursor )
    end

    private

    # @return [Nil]
    # @since 1.0.0
    def update_ui
      if @editor.selection.empty?
        Sketchup.status_text = 'Click a control point and hold down left mouse button to move it.'
      else
        Sketchup.status_text = 'Pick first point.'
      end
      Sketchup.vcb_label = 'Length'
      Sketchup.vcb_value = ( @length ) ? @length.to_s : ''
      nil
    end

    # @return [Nil]
    # @since 1.0.0
    def reset
      @ip_start.clear     
      @ip_mouse.clear
      @quickpick_entity = nil
      nil
    end

    # @return [Nil]
    # @since 1.0.0
    def reset_all
      reset()
      @cache = nil
      @vector = nil
      @length = nil
      nil
    end

    # @return [Geom::Vector3d,Nil]
    # @since 1.0.0
    def translation_vector
      return nil unless @vector
      if @length == 0.to_l
        vector = Geom::Vector3d.new( 0,0,0 )
      else
        vector = @vector.clone
        vector.length = @length
      end
      vector
    end
    
  end # class

end # module