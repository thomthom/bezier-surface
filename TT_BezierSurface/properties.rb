#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  module PropertiesWindow
    
    @window = nil
    
    # @return [Boolean]
    # @since 1.0.0
    def self.show
      if @window.nil?
        options = {
          :title => "#{PLUGIN_NAME} Properties",
          :pref_key => "#{PLUGIN::ID}_Properties",
          :left => 400,
          :top => 200,
          :width => 250,
          :height => 300,
          :resizable => true,
          :scrollable => false
        }
        @window = TT::GUI::ToolWindow.new( options )
        @window.theme = TT::GUI::Window::THEME_GRAPHITE
        
        label = TT::GUI::Label.new( 'Entity Info' )
        @window.add_control( label )
        @lbl_info = label
      end
      @window.show_window
      TT::SketchUp.activate_main_window
      true
    end
    
    # @return [Nil]
    # @since 1.0.0
    def self.close
      @window.close if @window.visible?
      nil
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def self.toggle
      if @window && @window.visible?
        self.close
        false
      else
        self.show
        true
      end
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def self.visible?
      @window && @window.visible?
    end
    
    
    # @return [Boolean]
    # @since 1.0.0
    def self.info=( string )
      if @window && @window.visible?
        @lbl_info.caption = string
      end
    end
    
  end # module PropertiesWindow

end # module