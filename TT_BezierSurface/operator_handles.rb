#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # @since 1.0.0
  class HandleOperator < Operator

    # @since 1.0.0
    def initialize( *args )
      super
      @cursor = TT::Cursor.get_id( :scale_n_ne )
      @mouse_start = Geom::Point3d.new( 0, 0, 0 )
      @cache = [] # Key: Handle - Value: Length
    end

    # @since 1.0.0
    def onLButtonDown( flags, x, y, view )
      super
      # Check if the user is interacting with a handle.
      if @entity_under_mouse.is_a?( BezierHandle )
        handle = @entity_under_mouse
        # Cache mouse and current handle data. Project the mouse coordinates to
        # the nearest point on the handle.
        @mouse_start = project_to_handle( handle, x, y, view )
        @handle_vector = handle.vector
      end
      false
    end

    # @since 1.0.0
    def onKeyDown( key, repeat, flags, view )
      super
      if @active && @scale
        scale_linked_handles( @scale )
        @surface.preview
      end
      false
    end

    # @since 1.0.0
    def onKeyUp( key, repeat, flags, view )
      super
      if @active && @scale
        scale_linked_handles( 1.0 )
        @surface.preview
      end
      false
    end

    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      super
      if @active && @entity_under_mouse
        # Reset flags and states.
        @active = false
        @mouse_start = nil
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
          @editor.model.start_operation( 'Scale Handle' )
          @surface.preview
          @cache = cache_handles( @entity_under_mouse )
        end

        tr = view.model.edit_transform
        handle = @entity_under_mouse
        # Find the point on the handle closest to where the cursor is.
        mouse_point = project_to_handle( handle, x, y, view )
        vertex = handle.vertex.position.transform( tr )
        # Find the reference vectors which we can use to calculate the scaling
        # ratio. The vectors origin from the handle's vertex (root).
        vertex_to_mouse_start = vertex.vector_to( @mouse_start )
        vertex_to_mouse_point = vertex.vector_to( mouse_point )
        # Calculate the new vector for the handle.
        vector = @mouse_start.vector_to( mouse_point )
        local_vector = vector.transform( tr.inverse )
        new_vector = @handle_vector + local_vector
        # Calculate the scaling ratio and update the handle
        @scale = vertex_to_mouse_point.length / vertex_to_mouse_start.length
        handle.length = new_vector.length
        # Scale the linked handles.
        if @key_ctrl
          scale_linked_handles( @scale )
        end
        # DEBUG: Output information on the scaling operation.
        # (!) Implement VCB support.
        world_handle = handle.vector.transform( tr )
        view.tooltip = "Scale: #{@scale}\nDistance: #{vector.length}\nLength: #{world_handle.length}"
        Sketchup.vcb_label = 'Scale'
        Sketchup.vcb_value = sprintf( '%.2f', @scale ) # (!) Use model settings!
        # Update mesh and viewport.
        @surface.preview
        view.refresh
        return true
      else
        # See if the mouse hovers over an editable handle and ensure the current
        # cursor reflects the orientation of the handle.
        @entity_under_mouse = pick_visible_handle( x, y, view )
        if @entity_under_mouse
          @cursor = handle_cursor( @entity_under_mouse, view )
          return true
        end
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

    private

    def cache_handles( handle )
      cache = {}
      for h in handle.linked_handles
        cache[h] = h.vector.length
      end
      cache
    end

    def scale_linked_handles( scale )
      for handle, length in @cache
        handle.length = length * scale
      end
    end

    # Returns a cursor resource ID based on a given BezierHandle entity
    #
    # @param [BezierHandle] handle
    # @param [Sketchup::View] view
    #
    # @return [Integer]
    # @since 1.0.0
    def handle_cursor( handle, view )
      tr = view.model.edit_transform
      pt1 = handle.position.transform( tr )
      pt2 = handle.vertex.position.transform( tr )
      vector = pt1.vector_to( pt2 )
      TT::Cursor.get_vector3d_cursor( vector, view )
    end

    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @return [BezierHandle|Nil]
    # @since 1.0.0
    def pick_visible_handle( x, y, view )
      visible = visible_handles()
      handles = @surface.pick_handles( x, y, view )
      handles.find { |handle| visible.include?( handle ) }
    end

    # @param [BezierHandle] handle
    # @param [Sketchup::View] view
    #
    # @return [Geom::Point3d]
    # @since 1.0.0
    def project_to_handle( handle, x, y, view )
      tr = view.model.edit_transform
      pt1 = handle.position.transform( tr )
      pt2 = handle.vertex.position.transform( tr )
      line = [ pt1, pt2 ]

      ray = view.pickray( x, y )
      Geom.closest_points( line, ray ).first
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

  end # class

end # module
