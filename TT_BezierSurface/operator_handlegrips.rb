#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  class HandleGripOperator < Operator

    # @since 1.0.0
    def initialize( *args )
      super
      @cursor = TT::Cursor.get_id( :hand )

      @entity_under_mouse = nil
      @mouse_position = nil
      @cache_vertex = nil
      @cache_gripper = nil
      @cache_normal = nil
    end

    # @since 1.0.0
    def onLButtonDown( flags, x, y, view )
      super
      if @entity_under_mouse
        gripper = @entity_under_mouse
        tr = view.model.edit_transform
        @mouse_position = gripper.position.transform( tr )
        @cache_gripper  = gripper.position.transform( tr )
        @cache_vertex   = gripper.vertex.position.transform( tr )
        @cache_normal   = gripper.vector.transform( tr )
      end
      false
    end

    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      super
      if @active && @entity_under_mouse
        # Reset flags and states.
        @active = false
        @mouse_position = nil
        @cache_gripper = nil
        @cache_normal = nil
        # Finish any operations in progress.
        @surface.update
        @editor.model.commit_operation
        view.invalidate
        return true
      end
      false
    end

    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      # Scale handle if left mouse button is held while moving the cursor.
      if @entity_under_mouse && flags & MK_LBUTTON == MK_LBUTTON
        # Activate preview mode when dragging begins.
        unless @active
          # (?) Is this really better? Or is it a good thing that the preview
          #     mesh is prepared on mouse down so the move action becomes as
          #     smooth as possible? Maybe the difference isn't that big.
          @active = true
          @editor.model.start_operation( 'Adjust Handle' )
          @surface.preview
        end

        centre = @cache_vertex
        radius = @cache_normal.length
        normal = @cache_normal.axes.y
        vector = @cache_normal
        line   = [ @cache_vertex, @cache_gripper ]

        @mouse_position = pick_closest_to_line( line, x, y, view )

        point = infer_from_line( line, x, y, view )
        point = snap_to_offset( point, centre, radius, view )
        point ||= infer_from_radius( centre, normal, radius, x, y, view )
        point ||= @mouse_position

        if point
          edit_tr = view.model.edit_transform
          gripper = @entity_under_mouse
          old_vector = gripper.vector
          gripper.position = point.transform( edit_tr.inverse )
          # Update linked handles
          # (?) Move to Handle.position= ?
          if gripper.linked?
            origin = gripper.vertex.position
            # Convert to handle coordinates, rotate, restore coordinates.
            local_tr = Geom::Transformation.new( origin, old_vector )
            x, y, z = gripper.vector.axes.map { |axis|
              axis.transform( local_tr.inverse )
            }
            rotation_tr = Geom::Transformation.axes( ORIGIN, x, y, z )
            tr = local_tr * rotation_tr * local_tr.inverse
            for handle in gripper.linked_handles
              new_point = handle.position.transform( tr )
              handle.position = new_point
            end
          end
          Sketchup.vcb_label = 'Length'
          Sketchup.vcb_value = gripper.vector.length.to_s
        end
        # Update mesh and viewport.
        @surface.preview
        view.refresh
        return true
      else
        @entity_under_mouse = pick_visible_handle_grip( x, y, view )
      end
      false
    end

    # @since 1.0.0
    def onSetCursor
      if @entity_under_mouse
        UI.set_cursor( @cursor )
        true
      else
        false
      end
    end

    # @since 1.0.0
    def draw( view )
      if @entity_under_mouse
        tr = view.model.edit_transform
        gripper = @cache_gripper
        vertex  = @cache_vertex
        normal  = @cache_normal
        line    = [vertex, gripper]
        live_grip = @entity_under_mouse.position.transform( tr )

        # Handle Axis
        if @cache_gripper
          s1 = view.pixels_to_model( 2000, vertex )
          s2 = view.pixels_to_model( 2000, gripper )
          pt1 = vertex.offset( normal.reverse, s1 )
          pt2 = gripper.offset( normal, s2 )
          view.line_width = 1
          view.line_stipple = '-'
          view.drawing_color = [128,128,128]
          view.draw( GL_LINES, pt1, pt2 )
        end

        # Handle Radius
        if @cache_gripper
          radius = normal.length
          vector = normal.axes.y
          circle = TT::Geom3d.circle( vertex, vector, radius, 48 )
          view.draw( GL_LINE_LOOP, circle )
        end

        # Inference
        if @mouse_position
          points = [live_grip, @mouse_position]
          view.line_width = INFERENCE_WIDTH
          view.line_stipple = INFERENCE_STYLE
          view.set_color_from_line( *points )
          view.draw( GL_LINES, points )
        end

        # Handle Gripper Fill
        @surface.draw_circles( view, [live_grip], CLR_HANDLE_ARM, VERTEX_SIZE, 0, true )
      end
      false
    end

    private

    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @return [BezierHandle|Nil]
    # @since 1.0.0
    def pick_visible_handle_grip( x, y, view )
      visible = visible_handles()
      handles = @surface.pick_handle_grips( x, y, view )
      handles.find { |handle| visible.include?( handle ) }
    end

    # @return [Array<BezierHandle>]
    # @since 1.0.0
    def visible_handles
      vertices = []
      for entity in @editor.selection
        if entity.is_a?( BezierVertex )
          vertices << entity
        elsif entity.respond_to?( :vertices )
          vertices.concat( entity.vertices )
        end
      end
      vertices.uniq!
      handles = vertices.map { |entity| entity.handles }
      handles.flatten!
      handles.uniq!
      handles
    end

    # @return [Geom::Point3d,Nil]
    # @since 1.0.0
    def pick_closest_to_line( line, x, y, view )
      mouse_ray = view.pickray( x, y )
      line_point, mouse_point = Geom.closest_points( line, mouse_ray )
      mouse_point
    end

    # @return [Geom::Point3d,Nil]
    # @since 1.0.0
    def snap_to_offset( point, origin, length, view )
      return nil unless point
      vector = origin.vector_to( point )
      offset_point = origin.offset( vector, length )
      distance = offset_point.distance( point )
      threshold = view.pixels_to_model( LINEAR_SNAP_THRESHOLD, offset_point )
      if distance <= threshold
        offset_point
      else
        point
      end
    end

    # @return [Geom::Point3d,Nil]
    # @since 1.0.0
    def infer_from_line( line, x, y, view )
      mouse_ray = view.pickray( x, y )
      line_point, mouse_point = Geom.closest_points( line, mouse_ray )
      distance = line_point.distance( mouse_point )
      threshold = view.pixels_to_model( LINEAR_SNAP_THRESHOLD, line_point )
      if distance <= threshold
        line_point
      else
        nil
      end
    end

    # @return [Geom::Point3d,Nil]
    # @since 1.0.0
    def infer_from_radius( centre, normal, radius, x, y, view )
      plane = [ centre, normal ]
      mouse_ray = view.pickray( x, y )
      mouse_point = Geom.intersect_line_plane( mouse_ray, plane )
      return nil unless mouse_point
      vector = centre.vector_to( mouse_point )
      radius_point = centre.offset( vector, radius )
      distance = radius_point.distance( mouse_point )
      threshold = view.pixels_to_model( RADIAL_SNAP_THRESHOLD, radius_point )
      if distance <= threshold 
        radius_point
      else
        nil
      end
    end

  end # class

end # module