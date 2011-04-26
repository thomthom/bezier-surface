#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  # @since 1.0.0
  class BezierEntity
    
    # @since 1.0.0
    def initialize
      @parent = nil
      @valid = true
      @linkables = []
      @linked = {}
    end
    
    # @return [String]
    # @since 1.0.0
    def typename
      'BezierEntity'
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def valid?
      @valid == true
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def deleted?
      !@valid
    end
    
    def invalidate!
      # Release any reference to other objects.
      @parent = nil
      @linked = {}
      # The entity is then flagged as invalid.
      @valid = false
    end
    
    # Assosiates an entity with the current BezierEdge. Use to keep track of
    # which entities use this edge.
    #
    # @param [BezierPatch,BezierEdge] entity
    #
    # @return [Boolean]
    # @since 1.0.0
    def link( entity )
      unless @linkables.any? { |acceptable| entity.is_a?( acceptable ) }
        raise ArgumentError, "Can't link #{self.class} with #{entity.class}. Invalid entity type."
      end
      # Keep record of each entity type in a hash lookup.
      @linked[ entity.class ] ||= []
      collection = @linked[ entity.class ]
      # Ensure there's only one entry for each entity.
      # (?) Should the Set class be used? Or does it not give enough performance
      # gain for small arrays?
      if collection.include?( entity )
        return false
      else
        collection << entity
        return true
      end
    end
    
    # De-assosiates an entity.
    #
    # @param [BezierPatch,BezierEdge] entity
    #
    # @return [Nil]
    # @since 1.0.0
    def unlink( entity )
      unless @linkables.any? { |acceptable| entity.is_a?( acceptable ) }
        raise ArgumentError, "Can't link #{self.class} with #{entity.class}. Invalid entity type."
      end
      # Look up the entity type in the hash table.
      @linked[ entity.class ] ||= []
      collection = @linked[ entity.class ]
      
      if collection.include?( entity )
        collection.delete( entity )
      else
        raise ArgumentError, 'Entity not linked.'
      end
      # (?) Return boolean instead of ArgumentError or nil?
      nil
    end
    
    # @return [String]
    # @since 1.0.0
    def inspect
      if @valid
        "<#{self.class}:#{TT.object_id_hex( self )}>"
      else
        "<Deleted:#{self.class}:#{TT.object_id_hex( self )}>"
      end
    end
    
  end # class BezierEntity

end # module