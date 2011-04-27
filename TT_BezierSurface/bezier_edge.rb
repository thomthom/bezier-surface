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
    
    attr_reader( :parent )
    attr_accessor( :control_points, :patches )
    
    # @param [Array<Geom::Point3d>] control_points Bezier control points
    #
    # @since 1.0.0
    def initialize( parent, edge_control_points )
      #TT.debug 'BezierEdge.new'
      super()
      @linkables = [BezierPatch]
      @parent = parent # BezierSurface
      @patches = []
      @control_points = []
      self.control_points = edge_control_points
    end
    
    # @return [String]
    # @since 1.0.0
    def typename
      'BezierEdge'
    end
    
    # @return [Array<BezierPatch>]
    # @since 1.0.0
    def patches
      fail_if_invalid()
      @linked[BezierPatch].dup
    end
    
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def end_control_points
      fail_if_invalid()
      [ @control_points.first, @control_points.last ]
    end
    
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points
      fail_if_invalid()
      @control_points.dup
    end
    alias :to_a :control_points
    
    # @param [Array<Geom::Point3d>] new_control_points
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points=( new_control_points )
      fail_if_invalid()
      @control_points = new_control_points
      
      BezierVertex.extend_all( new_control_points )
      for point in new_control_points
        point.link( self )
      end
      
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
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def direction
      fail_if_invalid()
      p1 = @control_points.first
      p2 = @control_points.last
      p1.vector_to( p2 )
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
      TT.debug( "Extrude Edge: (#{index}) #{self}" )
      TT.debug( "> Length: #{self.length(surface.subdivs).to_s}" )
      TT.debug( "> Reversed: #{edge_reversed}" )
      # </debug>
      
      # Use the connected edges to determine the direction of the extruded
      # bezier patch.
      prev_edge = edgeuse.previous.edge
      next_edge = edgeuse.next.edge
      
      # <debug>
      TT.debug( "> Prev Edge: #{prev_edge}" )
      TT.debug( "> Next Edge: #{next_edge}" )
      # </debug>
      
      # Cache the point for quicker access.
      pts = self.control_points
      pts_prev = prev_edge.control_points
      pts_next = next_edge.control_points
      
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

      # Extrude the new patch by the same length as the edge it's extruded from.
      # This should be an ok length that scales predictably in most conditions.
      length = self.length( surface.subdivs ) / 3.0
      
      # Generate the control points for the new patch.
      points = []
      pts.each_with_index { |point, index|
        points << point.clone
        points << point.offset( directions[index], length )
        points << point.offset( directions[index], length * 2 )
        points << point.offset( directions[index], length * 3 )
      }
      # Create the BezierPatch entity, add all entity assosiations.
      new_patch = QuadPatch.new( surface, points )
      new_patch.reversed = true if patch.reversed
      new_patch.set_edge( new_patch.edges.last, self )
      self.link( new_patch )
      
      # Add the patch to the surface and regenerate the mesh.
      model = Sketchup.active_model
      model.start_operation('Add Quad Patch', true)
      surface.add_patch( new_patch )
      surface.update( model.edit_transform )
      model.commit_operation
      
      new_patch
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
    
    # Returns an array of 3d points representing the bezier curve with the given
    # sub-division.
    #
    # @param [Integer] subdivs
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def segment( subdivs, transformation = nil )
      fail_if_invalid()
      points = TT::Geom3d::Bezier.points( @control_points, subdivs )
      if transformation
        points.map! { |point| point.transform!( transformation ) }
      end
      points
    end
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def start
      fail_if_invalid()
      @control_points.first
    end
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def end
      fail_if_invalid()
      @control_points.last
    end
    
  end # class BezierEdge

end # module