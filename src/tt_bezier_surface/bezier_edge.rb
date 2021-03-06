#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require File.join( TT::Plugins::BezierSurfaceTools::PATH, 'bezier_entity.rb' )


module TT::Plugins::BezierSurfaceTools

  # Collection of methods for managing the bezier patch edges and their
  # relationship to connected entities.
  #
  # @since 1.0.0
  class BezierEdge < BezierEntity

    # @param [BezierSurface] parent
    # @param [Array<Geom::Point3d>,Array<BezierControlPoint>] points
    #
    # @since 1.0.0
    def initialize( parent, points )
      #TT.debug 'BezierEdge.new'
      super()
      @links[ BezierControlPoint ] = []
      @links[ BezierPatch ] = []
      @parent = parent # BezierSurface
      if points.all? { |pt| pt.is_a?( BezierControlPoint ) }
        p1, p2, p3, p4 = points
        unless  p1.is_a?( BezierVertex ) &&
                p2.is_a?( BezierHandle ) &&
                p3.is_a?( BezierHandle ) &&
                p4.is_a?( BezierVertex )
          raise ArgumentError, 'Invalid ControlPoint'
        end
        @control_points = points.dup
      else
        @control_points = [
          BezierVertex.new( @parent, ORIGIN.clone ),
          BezierHandle.new( @parent, ORIGIN.clone ),
          BezierHandle.new( @parent, ORIGIN.clone ),
          BezierVertex.new( @parent, ORIGIN.clone )
        ]
        # Update positions
        self.control_points = points
      end
      # Link Control points with Edge
      @control_points.each { |control_point|
        control_point.link( self )
      }
      # Link vertices with handles
      self.start.link( self.start_handle )
      self.end.link( self.end_handle )
      # Link handles with vertices
      self.start_handle.link( self.start )
      self.end_handle.link( self.end )
    end

    # @return [Array<BezierPatch>]
    # @since 1.0.0
    def patches
      fail_if_invalid()
      @links[ BezierPatch ].dup
    end

    # @return [Array<BezierVertex>]
    # @since 1.0.0
    def vertices
      fail_if_invalid()
      [ @control_points.first, @control_points.last ]
    end

    # @return [Array<BezierHandle>]
    # @since 1.0.0
    def handles
      fail_if_invalid()
      @control_points[1,2]
    end

    # @return [BezierVertex]
    # @since 1.0.0
    def start
      fail_if_invalid()
      @control_points.first
    end

    # @return [BezierVertex]
    # @since 1.0.0
    def start=( new_vertex )
      fail_if_invalid()
      #old_vertex = @control_points[0]
      #@control_points[0] = replace_vertex( old_vertex, new_vertex )
      replace_vertex( @control_points[0], new_vertex )
      new_vertex
    end

    # @return [BezierVertex]
    # @since 1.0.0
    def end
      fail_if_invalid()
      @control_points.last
    end

    # @return [BezierVertex]
    # @since 1.0.0
    def end=( new_vertex )
      fail_if_invalid()
      #old_vertex = @control_points[3]
      #@control_points[3] = replace_vertex( old_vertex, new_vertex )
      replace_vertex( @control_points[3], new_vertex )
      new_vertex
    end

    # @return [BezierVertex]
    # @since 1.0.0
    def other_vertex( vertex )
      fail_if_invalid()
      unless vertices.include?( vertex )
        raise ArgumentError, 'Vertex not part of this edge.'
      end
      vertices.find { |v| v != vertex }
    end

    # @return [BezierVertex]
    # @since 1.0.0
    def replace_vertex( old_vertex, new_vertex )
      fail_if_invalid()
      unless old_vertex.is_a?( BezierVertex )
        raise ArgumentError, "Not a BezierVertex (#{old_vertex.class.name})"
      end
      unless new_vertex.is_a?( BezierVertex )
        raise ArgumentError, "Not a BezierVertex (#{new_vertex.class.name})"
      end
      unless old_vertex.links_to?( self )
        raise ArgumentError, "Vertex not connected to edge. (#{old_vertex})"
      end
      # Not sure if this would be better off raising error or returning nil.
      # Currently it works well to just return the vertex - but might it be
      # a better control to raise error? (Test units would probably solve that.)
      if new_vertex == old_vertex
        return new_vertex
      end
      # Update positions.
      new_vertex.position = old_vertex.position
      # Transfer links from old vertex to new vertex.
      for entity in old_vertex.linked
        entity.link( new_vertex )
        entity.unlink( old_vertex )
        next unless entity.is_a?( BezierEdge )
        entity.set_vertex!( old_vertex, new_vertex )
      end
      # Kill old vertex.
      old_vertex.invalidate!
      # Return the merged vertex.
      new_vertex
    end

    # @return [BezierHandle]
    # @since 1.0.0
    def start_handle
      fail_if_invalid()
      @control_points[1]
    end

    # @return [BezierHandle]
    # @since 1.0.0
    def end_handle
      fail_if_invalid()
      @control_points[2]
    end

    # @return [Geom::Vector3d]
    # @since 1.0.0
    def direction
      fail_if_invalid()
      p1 = @control_points.first.position
      p2 = @control_points.last.position
      p1.vector_to( p2 )
    end

    # @return [Length]
    # @since 1.0.0
    def length( subdivs )
      fail_if_invalid()
      total = 0.0
      points = segment( subdivs )
      for index in (0...points.size-1)
        pt1 = points[index]
        pt2 = points[index+1]
        total += pt1.distance( pt2 )
      end
      total.to_l
    end

    # @param [BezierPatch] subdivs
    #
    # @return [Boolean]
    # @since 1.0.0
    def reversed_in?( patch )
      fail_if_invalid()
      edgeuse = patch.get_edgeuse( self )
      # (?) Take into account reversed patch?
      edgeuse.reversed?
    end

    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points
      fail_if_invalid()
      @control_points.dup
    end
    alias :to_a :control_points

    # (?) Should this be positions= ?
    #
    # @param [Array<Geom::Point3d>] new_control_points
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points=( new_control_points )
      fail_if_invalid()
      TT::Point3d.extend_all( new_control_points )
      # Update positions
      new_control_points.each_with_index { |point, index|
        #@control_points[ index ].position = point
        @control_points[ index ].set( point )
      }
      @control_points.dup
    end

    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def positions
      fail_if_invalid()
      @control_points.map { |point|
        point.position
      }
    end
    #alias :to_a :positions

    # Returns an array of 3d points representing the bezier curve with the given
    # sub-division.
    #
    # @param [Integer] subdivs
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def segment( subdivs, transformation = nil )
      fail_if_invalid()
      points = TT::Geom3d::Bezier.points( self.positions, subdivs )
      if transformation
        points.map! { |point| point.transform!( transformation ) }
      end
      points
    end

    # @return [QuadPatch]
    # @since 1.0.0
    def extrude_quad_patch
      fail_if_invalid()
      if self.patches.size > 1
        raise ArgumentError, 'Can not extrude edge connected to more than one patch.'
      end

      surface = self.parent
      patch = self.patches[0]
      edgeuse = patch.get_edgeuse( self )
      edge_reversed = self.reversed_in?( patch )

      # <debug>
      index = patch.edge_index( self )
      #TT.debug( " " )
      #TT.debug( "Extrude Edge: (#{index}) #{self}" )
      #TT.debug( "> Length: #{self.length(surface.subdivs).to_s}" )
      #TT.debug( "> Reversed: #{edge_reversed}" )
      # </debug>

      # Use the connected edges to determine the direction of the extruded
      # bezier patch.
      prev_edge = edgeuse.previous.edge
      next_edge = edgeuse.next.edge

      # <debug>
      #TT.debug( "> Prev Edge: #{prev_edge}" )
      #TT.debug( "> Next Edge: #{next_edge}" )
      # </debug>

      # Cache the point for quicker access.
      pts = self.positions
      pts_prev = prev_edge.positions
      pts_next = next_edge.positions

      # Sort the points in a continuous predictable order.
      pts.reverse! if edge_reversed
      pts_prev.reverse! if prev_edge.reversed_in?( patch )
      pts_next.reverse! if next_edge.reversed_in?( patch )

      # Calculate the extrusion direction for the control points in the new patch.
      v1 = pts_prev[3].vector_to( pts_prev[2] ).reverse
      v2 = pts_next[0].vector_to( pts_next[1] ).reverse

      # (!) Unfinished - this is a quick hack. Need better Bezier Entity control
      # first.
      # The start and end control point vectors is used for the interior points.
      # In the finished product the interior points should be derived from
      # related interior points from the source patch in order to provide
      # a continous surface.
      directions = [ v1, v1, v2, v2 ]

      # Extrude the new patch by the same length as the edge adjesant edges.
      # This appear to be a bit more predictable then using the length of the
      # edge extruded.
      prev_length = prev_edge.length( surface.subdivs ) / 3.0
      next_length = next_edge.length( surface.subdivs ) / 3.0

      # Generate the control points for the new patch.
      points = []
      pts.each_with_index { |point, index|
        length = ( index < 2 ) ? prev_length : next_length
        points << point.clone
        points << point.offset( directions[index], length )
        points << point.offset( directions[index], length * 2 )
        points << point.offset( directions[index], length * 3 )
      }
      # Create the BezierPatch entity, add all entity assosiations.
      new_patch = QuadPatch.new( surface, points )

      merge_edge = new_patch.edges.last

      new_patch.replace_edge( merge_edge, self )

      # Add the patch to the surface. Calling method should be calling
      # Surface.update after this to refresh the mesh.
      surface.add_patch( new_patch )

      # (?) Merge edges that match 100%?

      new_patch
    end

    protected

    # Swaps one vertex reference with another.
    #
    # @return [BezierVertex]
    # @since 1.0.0
    def set_vertex!( old_vertex, new_vertex )
      # (?) protected
      unless old_vertex.is_a?( BezierVertex )
        raise ArgumentError, "Not a BezierVertex (#{old_vertex.class.name})"
      end
      unless new_vertex.is_a?( BezierVertex )
        raise ArgumentError, "Not a BezierVertex (#{new_vertex.class.name})"
      end
      unless old_vertex.links_to?( self )
        raise ArgumentError, "Vertex not connected to edge. (#{old_vertex})"
      end
      # Transfer links from old vertex to new
      if @control_points[0] == old_vertex
        @control_points[0] = new_vertex
      elsif @control_points[3] == old_vertex
        @control_points[3] = new_vertex
      else
        raise ArgumentError, "Unexpected Error! (#{old_vertex})"
      end
      new_vertex
    end

  end # class BezierEdge

end # module
