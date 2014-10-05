#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # @since 1.0.0
  class MoveTool < OperatorManager

    # @since 1.0.0
    def initialize( editor )
      super()
      add_operator( MoveOperator.new( editor ) )
    end

  end # class MoveTool

end # module
