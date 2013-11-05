#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # Caches drawing instructions so complex calculations for generating the
  # GL data can be reused.
  #
  # Redirect all Skethcup::View commands to a DrawCache object and call
  # #render in a Tool's #draw event.
  #
  # @since 1.0.0
  class DrawCache
    # (?) Move to TT_Lib ?
    
    # @param [Sketchup::View]
    #
    # @since 1.0.0
    def initialize( view )
      @view = view
      @commands = []
    end
    
    # Clears the cache. All drawing instructions are removed.
    #
    # @return [Nil]
    # @since 1.0.0
    def clear
      @commands.clear
      nil
    end
    
    # Draws the cached drawing instructions.
    #
    # @return [Sketchup::View]
    # @since 1.0.0
    def render
      view = @view
      for command in @commands
        view.send( *command )
      end
      view
    end

    # @return [Integer]
    # @since 1.0.0
    def cache_method( *args )
      m = ( Kernel.respond_to?( :__callee__) ) ? __callee__ : this_method
      @commands << args.unshift( m )
      @commands.size
    end

    # Cache drawing commands and data. These methods received the finsihed
    # processed drawing data that will be executed when #render is called.
    [
      :draw,
      :draw2d,
      :draw_line,
      :draw_lines,
      :draw_points,
      :draw_polyline,
      :draw_text,
      :drawing_color=,
      :line_stipple=,
      :line_width=,
      :set_color_from_line
    ].each { |symbol|
      #define_method( symbol ) { |*args|
      #  m = ( Kernel.respond_to?( :__callee__) ) ? __callee__ : this_method
      #  puts "CALL: #{m}"
      #  @commands << args.unshift( this_method )
      #  @commands.size
      #}
      # (i) `define_method` worked under Ruby 1.8, but not under 2.0 where it
      #     appear to capture a block instead. (Parent block of #each ?)
      #
      #     Aliasing methods appear to work on both.
      alias_method( symbol, :cache_method )
    }
    
    # Pass through methods to Sketchup::View so that the drawing cache object
    # can easily replace Sketchup::View objects in existing codes.
    #
    # @since 1.0.0
    def method_missing( *args )
      view = @view
      method = args.first
      if view.respond_to?( method )
        view.send(*args)
      else
        raise NoMethodError, "undefined method `#{method}' for #{self.class.name}"
      end
    end
    
    # @return [String]
    # @since 1.0.0
    def inspect
      hex_id = TT.object_id_hex( self )
      "#<#{self.class.name}:#{hex_id} Commands:#{@commands.size}>"
    end
    
    private
    
    # http://www.ruby-forum.com/topic/75258#895569
    def this_method
      ( caller[0] =~ /`([^']*)'/ and $1 ).intern
    end
    
  end # class DrawCache
  

end # module