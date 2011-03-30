#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  # Collection of methods for managing the bezier patch edges and their
  # relationship to connected entities.
  #
  # @since 1.0.0
  class BezierEdge
    
    attr_accessor( :control_points, :patches )
    
    # @param [Array<Geom::Point3d>] control_points Bezier control points
    #
    # @since 1.0.0
    def initialize( control_points )
      # (?) Require parent patch?
      # (!) Validate
      @control_points = control_points
      @patches = []
    end
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def direction
      p1 = @control_points.first
      p2 = @control_points.last
      p1.vector_to( p2 )
    end
    
    # @return [QuadPatch]
    # @since 1.0.0
    def extrude_quad_patch
      if self.patches.size > 1
        raise ArgumentError, 'Can not extrude edge connected to more than one patch.'
      end
      
      patch = self.patches[0]
      surface = patch.parent
      edge_reversed = self.reversed_in?( patch )
      
      # <debug>
      index = patch.edge_index( self )
      TT.debug( "Extrude Edge: (#{index}) #{self}" )
      TT.debug( "> Length: #{self.length(surface.subdivs).to_s}" )
      TT.debug( "> Reversed: #{edge_reversed}" )
      # </debug>
      
      # Use the connected edges to determine the direction of the extruded
      # bezier patch.
      prev_edge = patch.prev_edge( self )
      next_edge = patch.next_edge( self )
      
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
      length = self.length( surface.subdivs ) / 3
      
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
      self.link( new_patch )
      # (!) merge edges
      
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
      total = 0.0
      points = segment( subdivs )
      for index in (0...points.size-1)
        pt1 = points[index]
        pt2 = points[index+1]
        total += pt1.distance( pt2 )
      end
      total.to_l
    end
    
    # Assosiates an entity with the current BezierEdge. Use to keep track of
    # which entities use this edge.
    #
    # @param [BezierPatch] entity
    #
    # @return [Nil]
    # @since 1.0.0
    def link( entity )
      if entity.is_a?( BezierPatch )
        if @patches.include?( entity )
          raise ArgumentError, 'Entity already linked.'
        else
          @patches << entity
        end
      else
        raise ArgumentError, "Can't link BezierEdge with #{entity.class}. Invalid entity type."
      end
      nil
    end
    
    # De-assosiates an entity.
    #
    # @param [BezierPatch] entity
    #
    # @return [Nil]
    # @since 1.0.0
    def unlink( entity )
      if entity.is_a?( BezierPatch )
        if @patches.include?( entity )
          @patches.delete( entity )
        else
          raise ArgumentError, 'Entity not linked.'
        end
      else
        raise ArgumentError, "Can't unlink BezierEdge with #{entity.class}. Invalid entity type."
      end
      nil
    end
    
    # @param [BezierPatch] subdivs
    #
    # @return [Boolean]
    # @since 1.0.0
    def reversed_in?( patch )
      patch.edge_reversed?( self )
    end
    
    # Returns an array of 3d points representing the bezier curve with the given
    # sub-division.
    #
    # @param [Integer] subdivs
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def segment( subdivs, transformation = nil )
      points = TT::Geom3d::Bezier.points( @control_points, subdivs )
      if transformation
        points.map! { |point| point.transform!( transformation ) }
      end
      points
    end
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def start
      @control_points.first #.extend( TT::Point3d_Ex )
    end
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def end
      @control_points.last #.extend( TT::Point3d_Ex )
    end
    
    # Returns an array of 3d points representing control points.
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def to_a
      @control_points.dup
    end
    
  end # class BezierEdge

end # module