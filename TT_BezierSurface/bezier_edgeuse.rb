#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  # @since 1.0.0
  class BezierEdgeUse
    
    attr_reader( :patch )
    attr_accessor( :edge )
    
    # @param [BezierPatch] patch
    # @param [BezierEdge] edge
    # @param [Boolean] reversed
    #
    # @since 1.0.0
    def initialize( patch, edge, reversed=false )
      # (!) Validate
      @patch = patch
      @edge = edge
      @reversed = reversed
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def reversed?
      @reversed == true
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def reversed=( value )
      @reversed = value
    end
    
    # @return [BezierEdgeUse]
    # @since 1.0.0
    def next
      edgeuses = patch.edgeuses
      index = patch.edge_index( edge )
      array_index = ( index + 1 ) % edgeuses.size
      edgeuses[ array_index ]
    end
    
    # @return [BezierEdgeUse]
    # @since 1.0.0
    def previous
      edgeuses = patch.edgeuses
      index = patch.edge_index( edge )
      array_index = ( index - 1 ) % edgeuses.size
      edgeuses[ array_index ]
    end
    
  end # class BezierEdgeUse

end # module