#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  class SelectionTool < OperatorManager
    
    # @since 1.0.0
    def initialize( editor )
      super()

      @editor = editor
      @surface = editor.surface

      add_operator( GizmoOperator.new( editor ) )
      add_operator( PickSelectOperator.new( editor ) )
      add_operator( HandleOperator.new( editor ) )
      add_operator( RectangleSelectOperator.new( editor ) )
    end

    # @see TT::Plugins::BezierSurfaceTools#get_instructor_path
    #
    # @since 1.0.0
    def getInstructorContentDirectory
      real_path = File.join( PLUGIN::PATH, 'InstructorContent', 'Test' )
      adjusted_path = PLUGIN.get_instructor_path( real_path )
      TT::debug( adjusted_path )
      adjusted_path
    end

    # @since 1.0.0
    def enableVCB?
      #super
      true
    end

    # Updates the statusbar and VCB.
    #
    # @return [Nil]
    # @since 1.0.0
    def update_ui
      Sketchup.status_text = 'Click an entity to select and manipulate it.'
      Sketchup.vcb_label = 'Subdivisions'
      Sketchup.vcb_value = @surface.subdivs
      nil
    end

    # @since 1.0.0
    def activate    
      super
      update_ui()
      @editor.refresh_viewport
    end

    # @since 1.0.0
    def resume( view )
      update_ui()
      super
    end

    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      super
      update_ui()
    end

    # @since 1.0.0
    def onUserText( text, view )
      subdivs = text.to_i
      if SUBDIVS_RANGE.include?( subdivs )
        @editor.change_subdivisions( subdivs )
      else
        UI.beep
      end
      view.invalidate
      update_ui()
    end

    # @since 1.0.0
    def onSetCursor
      super
      true
    end

    # @since 1.0.0
    def draw( view )
      # <debug>
      t_start = Time.now
      # </debug>

      @editor.draw_cache.render
      super

      # <debug>
      elapsed = Time.now - t_start
      view.draw_text( [20,20,0], sprintf( 'Last Frame: %.4fs', elapsed ) )
      
      view.draw_text( [20,50,0], sprintf( 'Last Refresh Time: %.4fs', view.last_refresh_time ) )
      view.draw_text( [20,65,0], sprintf( 'Average Refresh Time: %.4fs', view.average_refresh_time ) )
      # </debug>
    end
    
  end # class SelectionTool

end # module