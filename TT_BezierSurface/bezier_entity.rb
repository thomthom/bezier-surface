#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  # @since 1.0.0
  class BezierEntity
    
    def initialize
      @valid = true
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
      # (!) Unlink
      @valid = false
    end
    
    # @return [String]
    # @since 1.0.0
    def inspect
      "<#{self.class}:#{TT.object_id_hex( self )}>"
    end
    
  end # class BezierEntity

end # module