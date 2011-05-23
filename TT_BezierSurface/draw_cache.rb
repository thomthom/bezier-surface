#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  class DrawCache
    
    def initialize
      @commands = []
    end
    
    def clear
      @commands.clear
    end
    
    def render( view )
      for command in @commands
        view.send( *command )
      end
    end
    
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
      define_method( symbol ) { |*args|
        @commands << args.unshift( this_method )
        @commands.size
      }
    }
    
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