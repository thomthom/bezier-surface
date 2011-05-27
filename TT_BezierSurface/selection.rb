#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # @since 1.0.0
  class Selection
    
    include Enumerable
    
    # @since 1.0.0
    def initialize
      @items = []
    end
    
    # @since 1.0.0
    def each
      @items.each { |i| yield(i) }
    end
    
    # @return [BezierEntity]
    # @since 1.0.0
    def [](index)
      @items[index]
    end
    alias :at :[]
    
    # @param [Array<BezierEntity>] entities
    #
    # @return [Integer]
    # @since 1.0.0
    def add( entities )
      ents = validate_entities( entities )
      @items.concat( ents )
      @items.uniq!
      entities.size
    end
    
    # @param [Array<BezierEntity>] entities
    #
    # @return [Integer]
    # @since 1.0.0
    def remove( entities )
      ents = validate_entities( entities )
      @items -= ents
      entities.size
    end
    
    # @param [Array<BezierEntity>] entities
    #
    # @return [Integer]
    # @since 1.0.0
    def toggle( entities )
      ents = validate_entities( entities )
      for e in ents
        if @items.include?( e )
          @items.delete( e )
        else
          @items << e
        end
      end
      entities.size
    end
    
    # @return [Nil]
    # @since 1.0.0
    def clear
      @items.clear
      nil
    end
    
    # @param [BezierEntity] entity
    #
    # @return [Boolean]
    # @since 1.0.0
    def contains?( entity )
      @items.include?( entity )
    end
    alias :include? :contains?
    
    # @return [Boolean]
    # @since 1.0.0
    def empty?
      @items.empty?
    end
    
    # @return [BezierEntity]
    # @since 1.0.0
    def first
      @items.first
    end
    
    # @return [Integer]
    # @since 1.0.0
    def length
      @items.length
    end
    alias :size :length
    alias :count :length
    alias :nitems :length
    
    # @return [BezierEntity]
    # @since 1.0.0
    def shift
      @items.shift
    end
    
    # @return [Array<BezierEntity>]
    # @since 1.0.0
    def to_a
      @items.to_a
    end
    
    # @return [Geom::BoundingBox]
    # @since 1.0.0
    def bounds
      bb = Geom::BoundingBox.new
      bb.add( positions ) unless empty?
      bb
    end
    
    # @return [Array<BezierControlPoint>]
    # @since 1.0.0
    def control_points
      control_points = []
      for entity in @items
        if entity.is_a?( BezierControlPoint )
          control_points << entity
        elsif entity.is_a?( BezierEdge )
          control_points.concat( entity.control_points )
        elsif entity.is_a?( BezierPatch )
          control_points.concat( entity.control_points.to_a )
        end
      end
      control_points.uniq!
      control_points
    end
    
    # @return [Array<BezierEdge>]
    # @since 1.0.0
    def edges
      @items.select { |cpt| cpt.is_a?( BezierEdge ) }
    end
    
    # @return [Array<BezierHandle>]
    # @since 1.0.0
    def handles
      @items.select { |cpt| cpt.is_a?( BezierHandle ) }
    end
    
    # @return [Array<BezierInteriorPoint>]
    # @since 1.0.0
    def interior_points
      @items.select { |cpt| cpt.is_a?( BezierInteriorPoint ) }
    end
    
    # @return [Array<BezierPatch>]
    # @since 1.0.0
    def patches
      @items.select { |cpt| cpt.is_a?( BezierPatch ) }
    end
    
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def positions
      control_points.map { |cpt| cpt.position }
    end
    
    # @return [Array<BezierVertex>]
    # @since 1.0.0
    def vertices
      @items.select { |cpt| cpt.is_a?( BezierVertex ) }
    end
    
    private
    
    # @param [BezierEntity,Array<BezierEntity>,#to_a] entity
    #
    # @return [Array<BezierVertex>]
    # @since 1.0.0
    def validate_entities( entities )
      if entities.is_a?( Array )
        entities
      elsif entities.respond_to?( :to_a )
        entities.to_a
      else
        [ entities ]
      end
    end
    
  end # class Selection
  

end # module