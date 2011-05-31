#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  module Observable
    
    # @return [Boolean]
    # @since 1.0.0
    def add_observer( observer )
      @observers ||= []
      @observers << observer
      true
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def remove_observer( observer )
      @observers ||= []
      result = @observers.delete?( observer )
      ( result ) ? true : false
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def clear_observers!
      @observers ||= []
      if @observers.empty?
        false
      else
        @observers.clear
        true
      end
    end
    
    private
    
    # @return [Boolean]
    # @since 1.0.0
    def trigger_observer( symbol, *args )
      @observers ||= []
      return false if @observers.empty?
      for observer in @observers
        next unless observer.respond_to?( symbol )
        observer.send( symbol, *args )
      end
      true
    end
  
  end # module Observable

end # module