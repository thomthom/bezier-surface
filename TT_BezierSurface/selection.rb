#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  class Selection
    
    include Enumerable
    
    def initialize
      @items = []
    end
    
    def each
      @items.each { |i| yield(i) }
    end
    
    def [](index)
      @items[index]
    end
    alias :at :[]
    
    def add( entities )
      ents = validate_entities( entities )
      @items.concat( ents )
      @items.uniq!
    end
    
    def remove( entities )
      ents = validate_entities( entities )
      @items -= ents
    end
    
    def toggle( entities )
      ents = validate_entities( entities )
      for e in ents
        if @items.include?( e )
          @items.delete( e )
        else
          @items << e
        end
      end
    end
    
    def clear
      @items.clear
    end
    
    def contains?(entity)
      @items.include?( entity )
    end
    alias :include? :contains?
    
    def empty?
      @items.empty?
    end
    
    def first
      @items.first
    end
    
    def length
      @items.length
    end
    alias :size :length
    alias :count :length
    alias :nitems :length
    
    def shift
      @items.shift
    end
    
    def to_a
      @items.to_a
    end
    
    private
    
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