#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  # @since 1.0.0
  class BezierEntity
    
    attr_reader( :parent, :links )
    
    # Base class of common methods for bezier related entities.
    #
    # ==Linkable Entities==
    # Related entities are linked together with #link and #unlink.
    #
    # BezierEntity use a hash @links to keep track of linked entities.
    # Subclasses must add the allowed linkable types to this hash. Key should be
    # entity class and value an array.
    #
    # @example
    #   class MySubClass < BezierEntity
    #   
    #     def initialize( parent )
    #       super()
    #       # Define linkable entities:
    #       @links[ BezierEdge ] = []
    #       @links[ BezierPatch ] = []
    #     end
    #
    #     def edges
    #       @links[ BezierEdge ].dup
    #     end
    #   
    #   end # class
    #
    # @since 1.0.0
    def initialize
      @parent = nil
      @valid = true
      @links = {} # Lookup table of related entities, grouped by type.
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
      @valid == false
    end
    
    # Invalidates the entity and releases any references it had to other
    # entities. Use after erasing/removing/replacing an entity which result
    # in an entity not to be used any more
    #
    # @return [Nil]
    # @since 1.0.0
    def invalidate!
      fail_if_invalid()
      # Release any reference to other objects.
      @parent = nil
      @links = {}
      # The entity is then flagged as invalid.
      @valid = false
      nil
    end
    
    # Assosiates an entity with the current BezierEntity. Use to keep track of
    # entities related to each other.
    #
    # @param [BezierEntity] entity
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
    # @param [BezierEntity] entity
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
    
    # @param [BezierEntity] entity
    #
    # @return [Boolean]
    # @since 1.0.0
    def used_by?( bezier_entity )
      fail_if_invalid()
      for type, entities in bezier_entity.links
        return true if entities.include?( self )
      end
      false
    end
    
    # @param [BezierEntity] entity
    #
    # @return [Boolean]
    # @since 1.0.0
    def links_to?( bezier_entity )
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