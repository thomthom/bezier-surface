#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  class GizmoOperator < Operator

    # @since 1.0.0
    def initialize( *args )
      super
      @gizmo = nil
    end

    # @since 1.0.0
    def activate    
      init_gizmo()
      false
    end

    # Called by BezierEditor when the selection or geometry has updated.
    # The viewport graphics then needs updating.
    #
    # @return [Boolean]
    # @since 1.0.0
    def refresh_viewport
      update_gizmo()
      false
    end

    # @since 1.0.0
    def onLButtonDown( flags, x, y, view )
      super
      return false if @editor.selection.empty?
      if @gizmo.onLButtonDown( flags, x, y, view )
        view.invalidate
        true
      else
        false
      end
    end

    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      super
      return false if @editor.selection.empty?
      if @gizmo.onLButtonUp( flags, x, y, view )
        view.invalidate
        true
      else
        false
      end
    end

    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      # Use view.refresh instead of view.invalidate as the latter doesn't
      # update often enough. View.refresh force the viewport to update.
      #
      # (?) Maybe limit how many refreshes are made for better performance?
      #     http://forums.sketchucation.com/viewtopic.php?f=180&t=37624
      #
      # (i) View.refresh require SketchUp 7.1+
      return false if @editor.selection.empty?
      if @gizmo.onMouseMove( flags, x, y, view )
        view.tooltip = @gizmo.tooltip
        view.refresh
        true
      else
        false
      end
    end

    # @since 1.0.0
    def draw( view )
      @gizmo.draw( view ) unless @editor.selection.empty?
      false
    end

    private
    
    # @return [Nil]
    # @since 1.0.0
    def init_gizmo
      tr = @editor.model.edit_transform
      xaxis = X_AXIS.transform( tr )
      yaxis = Y_AXIS.transform( tr )
      zaxis = Z_AXIS.transform( tr )
      
      @gizmo = TT::Gizmo::Manipulator.new( ORIGIN, xaxis, yaxis, zaxis )
      update_gizmo()
      
      @gizmo.on_transform_start { |action_name|
        @editor.model.start_operation( "Gizmo #{action_name}" )
        @surface.preview
      }
      
      @gizmo.on_transform { |t_increment, t_total, data|
        entities = @editor.selection.related_control_points
        @surface.transform_entities( t_increment, entities )
      }
      
      @gizmo.on_transform_end { |action_name|
        @surface.update
        @editor.model.commit_operation
      }
      
      nil
    end
    
    # Called after geometry and selection change.
    #
    # (?) Make use of observers?
    #
    # @return [Boolean]
    # @since 1.0.0
    def update_gizmo
      return false if @gizmo.active?

      tr = @editor.model.edit_transform
      control_points = @editor.selection.to_control_points
      positions = control_points.map { |cpt| cpt.position }
      average = TT::Geom3d.average_point( positions )
      @gizmo.origin = average.transform( tr )
      true
    end

  end # class

end # module