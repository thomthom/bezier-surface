#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # @since 1.0.0
  class PickSelectOperator < Operator

    # @since 1.0.0
    def initialize( *args )
      super

      @cursor_vertex        = TT::Cursor.get_id( :vertex )
      @cursor_vertex_add    = TT::Cursor.get_id( :vertex_add )
      @cursor_vertex_remove = TT::Cursor.get_id( :vertex_remove )
      @cursor_vertex_toggle = TT::Cursor.get_id( :vertex_toggle )

      @entity_under_mouse = nil
    end

    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      super

      # Ignore mouse drags.
      return false if left_mouse_drag?

      # Select entities by pick. The order of the type of entities picked is
      # important for the result as they would otherwise block each other.
      #
      # (?) Should the pick yield only one entity? That appear to be the way
      #     SketchUp do things.
      entities = []
      # Control Points
      picked = @surface.pick_editable_points( x, y, view )
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

      @editor.update_selection( entities, flags )

      view.invalidate
      true
    end

    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      @entity_under_mouse = @surface.pick_editable_point( x, y, view )
    end

    # @since 1.0.0
    def onLButtonDoubleClick( flags, x, y, view )
      # Pick patch and edges on double-click like the native Select tool in
      # SketchUp works with faces.
      patch = @surface.pick_patch( x, y, view )
      return false unless patch
      # Add patch and bordering edges.
      entities = patch.edges
      entities << patch
      # Update selection and viewport.
      @editor.update_selection( entities, flags )
      view.invalidate
      true
    end

    # @since 1.0.0
    def onSetCursor
      return false unless @entity_under_mouse
      if  @entity_under_mouse.is_a?( BezierVertex ) ||
          @entity_under_mouse.is_a?( BezierInteriorPoint )
        if @key_ctrl && @key_shift
          cursor = @cursor_vertex_remove
        elsif @key_ctrl
          cursor = @cursor_vertex_add
        elsif @key_shift
          cursor = @cursor_vertex_toggle
        else
          cursor = @cursor_vertex
        end
        UI.set_cursor( cursor )
        return true
      else
        false
      end
    end

  end # class

end # module
