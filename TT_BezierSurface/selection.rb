#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @note Supports SketchUp's native +SelectionObserver+.
  # @see http://code.google.com/apis/sketchup/docs/ourdoc/selectionobserver.html
  #
  # @since 1.0.0
  class Selection
    
    include Enumerable
    include Observable
    
    attr_reader( :model )
    attr_reader( :editor )
    
    # @param [BezierSurfaceEditor,Sketchup::Model] parent
    #
    # @since 1.0.0
    def initialize( parent )
      @items = []
      if parent.is_a?( BezierSurfaceEditor )
        @editor = parent
        @model = parent.model
      elsif parent.is_a?( Sketchup::Model )
        @editor = nil
        @model = parent
      else
        raise ArgumentError, 'Parent must be BezierSurfaceEditor or Model.'
      end
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
      trigger_observer( :onSelectionBulkChange, self ) unless ents.empty?
      ents.size
    end
    
    # @param [Array<BezierEntity>] entities
    #
    # @return [Integer]
    # @since 1.0.0
    def remove( entities )
      ents = validate_entities( entities )
      @items -= ents
      trigger_observer( :onSelectionBulkChange, self ) unless ents.empty?
      ents.size
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
      trigger_observer( :onSelectionBulkChange, self ) unless ents.empty?
      ents.size
    end
    
    # @return [Nil]
    # @since 1.0.0
    def clear
      trigger_observer( :onSelectionCleared, self ) unless @items.empty?
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
      result = @items.shift
      if result
        trigger_observer( :onSelectionBulkChange, self )
      end
      result
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
      @items.select { |cpt| cpt.is_a?( BezierControlPoint ) }
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
    
    # @return [Array<BezierControlPoint>]
    # @since 1.0.0
    def to_control_points
      result = []
      for entity in @items
        if entity.is_a?( BezierControlPoint )
          result << entity
        elsif entity.is_a?( BezierEdge )
          result.concat( entity.control_points )
        elsif entity.is_a?( BezierPatch )
          result.concat( entity.control_points.to_a )
        end
      end
      result.uniq!
      result
    end
    
    # @return [Array<BezierVertex>]
    # @since 1.0.0
    def to_vertices
      result = []
      for entity in @items
        if entity.is_a?( BezierVertex )
          result << entity
        elsif entity.is_a?( BezierEdge )
          result.concat( entity.vertices )
        elsif entity.is_a?( BezierPatch )
          result.concat( entity.vertices )
        end
      end
      result.uniq!
      result
    end
    
    # (?) Move to Editor?
    #
    # @return [Array<BezierControlPoint>]
    # @since 1.0.0
    def related_control_points
      result = []
      for entity in @items
        if entity.is_a?( BezierControlPoint )
          result << entity
        elsif entity.is_a?( BezierEdge )
          result.concat( entity.control_points )
        elsif entity.is_a?( BezierPatch )
          result.concat( entity.control_points.to_a )
        end
      end
      result.uniq!
      for entity in result.to_a
        if entity.is_a?( BezierVertex )
          result.concat( entity.handles )
        end
      end
      result.uniq!
      result
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