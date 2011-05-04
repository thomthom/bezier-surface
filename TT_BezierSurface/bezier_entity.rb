#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  # @since 1.0.0
  class BezierEntity
    
    attr_reader( :parent )
    
    # @since 1.0.0
    def initialize
      @parent = nil
      @valid = true
      @links = {}
      @typename = self.class.name.split('::').last.freeze
    end
    
    # @return [String]
    # @since 1.0.0
    def typename
      @typename.dup
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
      fail_if_invalid()
      # Release any reference to other objects.
      @parent = nil
      @links.each_key { |key|
        @links[ key ] = []
      }
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
      fail_if_invalid()
      
      type = @links.keys.find { |acceptable| entity.is_a?( acceptable ) }
      unless type
        raise ArgumentError, "Can't link #{self.class.name} with #{entity.class.name}. Invalid entity type."
      end
      # Keep record of each entity type in a hash lookup.
      @links[ type ] ||= []
      collection = @links[ type ]
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
      fail_if_invalid()
      
      type = @links.keys.find { |acceptable| entity.is_a?( acceptable ) }
      unless type
        raise ArgumentError, "Can't link #{self.class.name} with #{entity.class.name}. Invalid entity type."
      end
      # Look up the entity type in the hash table.
      @links[ type ] ||= []
      collection = @links[ type ]
      
      if collection.include?( entity )
        collection.delete( entity )
      else
        raise ArgumentError, 'Entity not linked.'
      end
      # (?) Return boolean instead of ArgumentError or nil?
      nil
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def used_by?( bezier_entity )
      fail_if_invalid()
      for type, entities in @links
        return true if entities.include?( bezier_entity )
      end
      false
    end
    
    # @return [String]
    # @since 1.0.0
    def inspect
      name = self.class.name.split('::').last
      hex_id = TT.object_id_hex( self )
      if @valid
        "#<#{name}:#{hex_id}>"
      else
        "#<Deleted:#{name}:#{hex_id}>"
      end
    end
    
    private
    
    # @return [Nil]
    # @since 1.0.
    def fail_if_invalid
      unless @valid
        raise TypeError, "Reference to deleted #{self.typename}"
      end
      nil
    end
    
  end # class BezierEntity

end # module