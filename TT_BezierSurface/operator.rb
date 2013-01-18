#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  class Operator

    extend TT::BooleanAttributes

    # `True` when the tool is busy with an operation or action which requires a
    # lock to all the events triggered by the Tool class until this flag is
    # reset to `false`.
    # @since 1.0.0
    battr_accessor :active

    def initialize( editor )
      @editor = editor
      @surface = editor.surface
      # Indicate if the operator is busy with an action and claims a lock to all
      # events until this state returns to false.
      @active = false
      # Make key states availible outside key events.
      @key_ctrl = false
      @key_shift = false
      # Detect mouse drags.
      @left_mouse_drag = false
      @left_mouse_down = Geom::Point3d.new( 0, 0, 0 )
    end

    # @since 1.0.0
    def deactivate( view )
      view.invalidate
      false
    end

    # @since 1.0.0
    def resume( view )
      @editor.refresh_viewport
      # (!) view.invalidate doesn't refresh the viewport fast enough, so it
      #     appear to be quite laggy. Forcing with refresh makes it appear
      #     smoother, but Editor.update_viewport_cache needs to be improved.
      #
      #     It may possibly be smarter way to cache this stuff. Like not
      #     regenerating the edge and patch data used to draw the Edges and
      #     Patches.
      #
      #     Vertices, Handles and Gizmo and the like needs to be regenerated as
      #     they are a type of UI elements that appear 2D but drawn in 3D space
      #     so they need to be recalculated on each viewportchange regardless.
      #
      #     When the Bezier is moved to C it might provide enough performance
      #     increase - at least initially. If the calculation load is less it
      #      -might- be enough to revert to use #invalidate.
      view.refresh
      false
    end

    # @since 1.0.0
    def getMenu( menu )
      @editor.context_menu( menu )
    end

    # @since 1.0.0
    def onKeyDown( key, repeat, flags, view )
      @key_ctrl  = true if key == COPY_MODIFIER_KEY
      @key_shift = true if key == CONSTRAIN_MODIFIER_KEY
      false
    end
    
    # @since 1.0.0
    def onKeyUp( key, repeat, flags, view )
      @key_ctrl  = false if key == COPY_MODIFIER_KEY
      @key_shift = false if key == CONSTRAIN_MODIFIER_KEY
      false
    end

    # @since 1.0.0
    def onLButtonDown( flags, x, y, view )
      @left_mouse_down = false
      @left_mouse_down = Geom::Point3d.new( x, y, 0 )
      false
    end

    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      # Detect mouse drag.
      dx = ( @left_mouse_down.x - x ).abs
      dy = ( @left_mouse_down.y - y ).abs
      @left_mouse_drag = dx > 2 || dy > 2
      false
    end

    private

    # @since 1.0.0
    def left_mouse_drag?
      @left_mouse_drag == true
    end

  end # class

end # module