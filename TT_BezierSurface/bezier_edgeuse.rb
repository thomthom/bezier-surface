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
      #TT.debug 'BezierEdgeUse.new'
      # (!) Validate
      @patch = patch
      @edge = edge
      @reversed = reversed
    end
    
    def edge=( new_edge )
      @edge.unlink( @patch )
      new_edge.link( @patch )
      @edge = new_edge
      new_edge
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
    
    def inspect
      "<#{self.class}:#{TT.object_id_hex( self )}>"
    end
    
  end # class BezierEdgeUse

end # module