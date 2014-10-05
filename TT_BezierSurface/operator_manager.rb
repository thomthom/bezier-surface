#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # Delegates Tool events to Operator instances which can claim locks on the
  # events by setting their #active property to true.
  #
  # A Tool should inherit from this class and add the operators it want to make
  # use of.
  #
  # @note Remember to call ´super´ in Tools that need to implement custom
  #       handling of the tool events.
  #
  # @since 1.0.0
  class OperatorManager

    # @note #initialize method of sub-class needs to call #super() since this
    #       method doesn't accept any arguments.
    #
    # @since 1.0.0
    def initialize
      @operators = []
    end

    # @since 1.0.0
    def active_operator
      @operators.find { |operator| operator.active? }
    end

    # Pushes an operator to the stack. The order which the operators are added
    # is important as an operator can prevent events from propagating.
    #
    # @param [Operator] operator
    #
    # @return [Operator]
    # @since 1.0.0
    def add_operator( operator )
      @operators << operator
    end
    alias :<< :add_operator

    # @param [Operator] operator
    # @param [Symbol] method_id
    # @param [Array] args Method arguments.
    #
    # @return [Boolean,Nil] Nil when the operator didn't respond to the event.
    # @since 1.0.0
    def trigger_event( operator, method_id, args )
      if operator.respond_to?( method_id )
        operator.send( method_id, *args )
      else
        nil
      end
    end

    # @param [Symbol] method_id
    # @param [Array] args Method arguments.
    #
    # @return [Boolean] True means the event want to prevent propagation.
    # @since 1.0.0
    def relay_event( method_id, args )
      # Forward event to active operator.
      # If there is no active tool the event is forwarded to all operators
      # until one of them return a true value - which then means it's
      # capturing the events.
        # <debug>
        #puts "> Relay: #{method_id} (#{args.size})"
        #ignore = [:enableVCB?,:onMouseMove,:getExtents,:draw,:onSetCursor].include?(method_id)
        #ignore = ![:onSetCursor].include?(method_id)
        #puts ' ' unless ignore
        #p method_id unless ignore
        # </debug>
      if operator = active_operator()
        #puts '> Active operator' unless ignore # <debug/>
        return trigger_event( operator, method_id, args )
      else
        #puts '> Operators' unless ignore # <debug/>
        for operator in @operators
          #p operator.class unless ignore # <debug/>
          prevent_bubble = trigger_event( operator, method_id, args )
          #p prevent_bubble unless ignore # <debug/>
          return prevent_bubble if prevent_bubble
        end # for
      end
      false
    end

    # The key events doesn't trigger #onSetCursor which will lead to the cursor
    # not being updated immediatly if it's representing the state of a key.
    # A forced call is injected to address this.
    #
    # @since 1.0.0
    def onKeyDown( *args )
      capture = relay_event( :onKeyDown, args )
      relay_event( :onSetCursor, [] )
      capture
    end

    # @see #onKeyDown
    #
    # @since 1.0.0
    def onKeyUp( *args )
      capture = relay_event( :onKeyUp, args )
      relay_event( :onSetCursor, [] )
      capture
    end

    [
    :onMouseEnter,
    :onMouseLeave,
    :onMouseMove,
    :onLButtonDown,
    :onLButtonUp,
    :onLButtonDoubleClick,
    # (i) Middle mouse button actions will block the native orbit function.
    #     Unless this is explicitly required these events are ignored.
    #:onMButtonDown,
    #:onMButtonUp,
    #:onMButtonDoubleClick,
    :onRButtonDown,
    :onRButtonUp,
    :onRButtonDoubleClick,
    #:onKeyDown,
    #:onKeyUp,
    :onUserText,
    :onReturn,
    :onCancel,
    :onSetCursor,
    :getMenu,
    :activate,
    :deactivate,
    :resume,
    :suspend,
    :getInstructorContentDirectory,
    :enableVCB?,
    :getExtents,
    :draw,
    # Custom events
    :refresh_viewport # (?) Better name?
    ].each { |method_id|
      define_method( method_id ) { |*args|
        relay_event( method_id, args )
      }
    }

  end # class

end # module
