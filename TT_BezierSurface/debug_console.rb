#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # @since 1.0.0
  class DebugConsole

    attr_accessor( :output, :external )

    # @param [Boolean] output
    # @param [Boolean] external
    #
    # @since 1.0.0
    def initialize( output = true, external = false )
      @output = output
      @external = external
    end

    # @since 1.0.0
    def log( *args )
      if output
        if external
          TT.debug( *args )
        else
          puts( *args )
        end
      else
        return false
      end
    end

  end # class DebugConsole

end # TT::Plugins::BezierSurfaceTools
