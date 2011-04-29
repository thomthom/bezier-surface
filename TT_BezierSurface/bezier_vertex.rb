#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  # @since 1.0.0
  module BezierVertex
  
    include TT::Point3d_Ex
    
    def edges
      @links ||= {}
      @links[BezierEdge] ||= []
      @links[BezierEdge].dup
    end
    
    def patches
      @links ||= {}
      @links[BezierPatch] ||= []
      @links[BezierPatch].dup
    end
    
    # Assosiates an entity with the current BezierEdge. Use to keep track of
    # which entities use this edge.
    #
    # @param [BezierPatch,BezierEdge] entity
    #
    # @return [Nil]
    # @since 1.0.0
    def link( entity )
      #TT.debug ' '
      #TT.debug "BezierVertex.link (#{self.inspect})"
      #TT.debug entity
      if entity.is_a?( BezierPatch ) || entity.is_a?( BezierEdge )
        @links ||= {}
        @links[ entity.class ] ||= []
        collection = @links[ entity.class ]
        unless collection.include?( entity )
          collection << entity
          #TT.debug "Added! (#{collection.size})"
        end
      else
        raise ArgumentError, "Can't link BezierVertex with #{entity.class}. Invalid entity type."
      end
      #TT.debug ' '
      nil
    end
    
    # De-assosiates an entity.
    #
    # @param [BezierPatch,BezierEdge] entity
    #
    # @return [Nil]
    # @since 1.0.0
    def unlink( entity )
      if entity.is_a?( BezierPatch ) || entity.is_a?( BezierEdge )
        @links ||= {}
        @links[ entity.class ] ||= []
        collection = @links[ entity.class ]
        if collection.include?( entity )
          collection.delete( entity )
        else
          raise ArgumentError, 'Entity not linked.'
        end
      else
        raise ArgumentError, "Can't unlink BezierVertex with #{entity.class}. Invalid entity type."
      end
      nil
    end
    
    # Extends all the points (+Geom::Point3d+ and +Array+ in +points+) with the
    # +TT::Point3d_Ex+ mix-in module.
    #
    # All +Array+ objects that represent a 3d point will be converted into
    # +Geom::Point3d+ before being extended.
    #
    # @param [Array<Geom::Point3d>] points
    #
    # @return [Array<TT::Point3d_Ex>] Geom::Point3d objects extended by TT::Point3d_Ex
    # @since 2.5.0
    def self.extend_all( points )
      raise ArgumentError, 'Argument must be an array.' unless points.is_a?( Array )
      extended_points = []
      for point in points
        if point.is_a?( Geom::Point3d )
          point_ex = point
        elsif point.is_a?( Array )
          next unless point.size == 3 && point.all? { |n| n.is_a?( Numeric ) }
          point_ex = Geom::Point3d.new( point.x, point.y, point.z )
        elsif point.respond_to?( :position )
          position = point.position
          point_ex = position if position.is_a?( Geom::Point3d )
        end
        point_ex.extend( self ) unless point_ex.is_a?( self )
        extended_points << point_ex
      end
      extended_points
    end
    
    def inspect
      "<#{self.class}:#{TT.object_id_hex( self )}>"
    end
    
  end # module BezierVertex

end # module