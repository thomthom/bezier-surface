#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # @since 1.0.0
  class RectangleSelectOperator < Operator

    # @since 1.0.0
    def initialize( *args )
      super

      @selection_rectangle = SelectionRectangle.new( @surface )

      @cursor         = TT::Cursor.get_id( :select )
      @cursor_add     = TT::Cursor.get_id( :select_add )
      @cursor_remove  = TT::Cursor.get_id( :select_remove )
      @cursor_toggle  = TT::Cursor.get_id( :select_toggle )
    end

    # @since 1.0.0
    def onLButtonDown( flags, x, y, view )
      super
      @selection_rectangle.start = Geom::Point3d.new( x, y, 0 )
      false
    end

    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      super

      # Ensure states are reset.
      @active = false

      # Ignore if mouse was not dragged.
      return false unless left_mouse_drag?

      # Select entities within the selection rectangle.
      s = @surface
      availible = s.vertices + s.manual_interior_points + s.edges + s.patches
      entities = @selection_rectangle.selected_entities( view, availible )
      # Update selection and viewport.
      @editor.update_selection( entities, flags )
      @selection_rectangle.reset
      view.invalidate
      true
    end

    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      if flags & MK_LBUTTON == MK_LBUTTON
        @active = true
        @selection_rectangle.end = Geom::Point3d.new( x, y, 0 )
        view.refresh
        true
      else
        @active = false
        view.invalidate
        false
      end
    end

    # @since 1.0.0
    def draw( view )
      @selection_rectangle.draw( view )
      false
    end

    # @since 1.0.0
    def onSetCursor
      if @key_ctrl && @key_shift
        cursor = @cursor_remove
      elsif @key_ctrl
        cursor = @cursor_add
      elsif @key_shift
        cursor = @cursor_toggle
      else
        cursor = @cursor
      end
      UI.set_cursor( cursor )
      true
    end

  end # class

end # module
