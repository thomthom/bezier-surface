#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  # @since 1.0.0
  class BinaryParser
    
    # Data Types
    FLOAT = 'G'.freeze # Double-precision float, network (big-endian) byte order
    INTEGER = 'i'.freeze # Signed Integer
    BOOLEAN = 'C'.freeze # Unsigned char
    # Short notations
    INT = INTEGER
    BOOL = BOOLEAN
    
    # @example Writing data
    #  bp = BinaryParser.new( BinaryParser::INT )
    #  bp.insert( 123 )
    #  bp.insert( 456 )
    #  bp.insert( 789 )
    #  base64data = bp.write
    #
    # @example Reading data
    #  bp = BinaryParser.new( BinaryParser::INT )
    #  dataset = bp.read( base64data )
    #  # dataset = [
    #  #   [ 123 ],
    #  #   [ 456 ],
    #  #   [ 789 ]
    #  # ]
    #
    # @example Writing complex data
    #  bp = BinaryParser.new( BinaryParser::INT, BinaryParser::BOOL )
    #  bp.insert( 123, 1 )
    #  bp.insert( 456, 0 )
    #  bp.insert( 789, 0 )
    #  base64data = bp.write
    #
    # @example Reading complex data
    #  bp = BinaryParser.new( BinaryParser::INT, BinaryParser::BOOL )
    #  dataset = bp.read( base64data, 3 )
    #  # dataset = [
    #  #   [ 123, 1 ],
    #  #   [ 456, 0 ],
    #  #   [ 789, 0 ]
    #  # ]
    #
    # @param [String|Array] template Data structure
    #
    # @since 1.0.0
    def initialize( *args )
      if args.size == 1
        template = args[0]
        if template.is_a?( String )
          @template = [ template ]
        elsif template.is_a?( Array )
          @template = template.dup
        else
          raise ArgumentError, 'Invalid template.'
        end
      else
        @template = args.dup
      end
      @dataset = []
    end
    
    # @since 1.0.0
    def clear
      @dataset.clear
    end
    
    # @param [Array] data
    #
    # @since 1.0.0
    def insert( data )
      unless data.is_a?( Array )
        raise ArgumentError, 'Data must be enclosed in an array.'
      end
      unless data.size == @template.size
        raise ArgumentError, "Data array must be same size as template. (#{data.size} for #{@template.size})"
      end
      @dataset << data
    end
    
    # @param [String] base64data Base64 encoded data string
    # @param [Integer] dataset_size Number of datasets in base64data
    #
    # @since 1.0.0
    def read( base64data, dataset_size=nil )
      if @template.size > 1 && dataset_size.nil?
        raise ArgumentError, 'Dataset size must be spesified for complex templates.'
      end
      if dataset_size && !dataset_size.is_a?( Numeric )
        raise ArgumentError, 'Dataset size must be an integer.'
      end
      if dataset_size
        pattern = @template.join * dataset_size
      else
        pattern = "#{@template.join}*"
      end
      raw_data = TT::Binary.decode64( base64data )
      raw_data.unpack( pattern )
    end
    
    # @param [Array] dataset If not spesified, the internal dataset if used.
    #
    # @since 1.0.0
    def write( dataset=nil )
      if dataset.nil?
        dataset = @dataset
      end
      if @template.size > 1
        pattern = @template.join * @dataset.size
      else
        pattern = "#{@template.join}*"
      end
      binary_data = dataset.flatten.pack( pattern )
      TT::Binary.encode64( binary_data )
    end
    
  end # class BinaryParser

  
end # module