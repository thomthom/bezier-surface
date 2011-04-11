#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # Tool creating Quad Patches.
  #
  # @since 1.0.0
  class CreatePatchTool
    
    # @since 1.0.0
    def initialize
      @ip_start = Sketchup::InputPoint.new
      @ip_mouse = Sketchup::InputPoint.new
      @subdivs = SUBDIVS_DEFAULT
      
      @cursor = TT::Cursor.get_id(:rectangle)
    end
    
    # @since 1.0.0
    def getInstructorContentDirectory
      real_path = File.join( PLUGIN::PATH, 'InstructorContent', 'Test' )
      adjusted_path = PLUGIN.get_instructor_path( real_path )
      TT::debug( adjusted_path )
      adjusted_path
    end
    
    # Reset the tool to the initial state.
    #
    # @since 1.0.0
    def reset
      @ip_start = Sketchup::InputPoint.new
      @ip_mouse = Sketchup::InputPoint.new
    end
    
    # Updates the UI with relevant information to the user.
    #
    # @since 1.0.0
    def update_ui
      if @ip_start.valid?
        Sketchup.status_text = 'Pick Opposite Corner.'
      else
        Sketchup.status_text = 'Pick Start Point.'
      end
    end
    
    # @since 1.0.0
    def activate
      update_ui()
    end
    
    # @since 1.0.0
    def deactivate(view)
      view.invalidate
    end
    
    # @since 1.0.0
    def resume(view)
      view.invalidate
      update_ui()
    end
    
    # @since 1.0.0
    def getExtents
      bb = Geom::BoundingBox.new
      points = corner_points()
      bb.add( points ) if points
      bb
    end
    
    # @since 1.0.0
    def onCancel(reason, view)
      TT.debug( 'CreatePatchTool.onCancel' )
      case reason
      when 0 # ESC
        TT.debug( '> ESC' )
        reset()
      when 1 # Reactivate Tool
        TT.debug( '> Reactivate' )
        reset()
      when 2 # Undo
        TT.debug( '> Undo' )
      end
      update_ui()
      view.invalidate
    end
    
    # @since 1.0.0
    def onUserText(text, view)
      # Ensure the subdivision is within sensible ranges. Prevents the user from
      # hanging the computer when unreasonable values are entered.
      subdivs = text.to_i
      if SUBDIVS_RANGE.include?( subdivs )
        @subdivs = subdivs
      else
        UI.beep
      end
    end
    
    # @since 1.0.0
    def onMouseMove(flags, x, y, view)
      view.invalidate if @ip_mouse.pick(view, x, y)
      view.tooltip = @ip_mouse.tooltip
    end
    
    # @since 1.0.0
    def onLButtonUp(flags, x, y, view)
      if @ip_start.valid?
        # Validate input data.
        points = corner_points()
        return if points.nil?
        
        # Calculate group transformation.
        origin = @ip_start.position
        x_point = points[1]
        y_point = points[2]
        x_axis = origin.vector_to( x_point )
        y_axis = origin.vector_to( y_point )
        return unless x_axis.valid? && y_axis.valid?
        
        # Calculate control points.
        p1 = ORIGIN.clone
        p2 = p1.offset( X_AXIS, x_axis.length )
        p3 = p1.offset( Y_AXIS, y_axis.length )
        p4 = p3.offset( X_AXIS, x_axis.length )
        controlpoints = interpolate_points( [p1, p2, p3, p4] )
        
        # Create Patch
        TT::Model.start_operation('Create Bezier Surface')
        group = view.model.active_entities.add_group
        group.name = 'Bezier Surface'
        group.transformation = Geom::Transformation.new( origin, x_axis, y_axis )
        surface = BezierSurface.new( group )
        patch = QuadPatch.new( surface, controlpoints )
        surface.add_patch( patch )
        surface.update( view.model.edit_transform )
        view.model.commit_operation
        view.model.selection.clear
        view.model.selection.add( group )
        
        # Deactivate tool
        # Activate select tool as it is a plausible next step for the user.
        # Early implementation popped this tool off the stack, but this is
        # safer in case other tools has been pushed to the stack.
        view.model.select_tool( nil )
      else
        @ip_start.copy!( @ip_mouse )
        #view.lock_inference(@ip_start) unless @ip_start.face.nil?
        update_ui()
      end
    end
    
    # @since 1.0.0
    def draw(view)
      # InputPoints
      @ip_start.draw(view) if @ip_start.valid?
      @ip_mouse.draw(view) if @ip_mouse.valid?
      # Mesh Control Points
      return unless @ip_start.valid? && @ip_mouse.valid?
      pts = corner_points()
      return unless pts
      pts = interpolate_points( pts )
      return unless pts
      # Fill
      if TT::SketchUp.support?( TT::SketchUp::COLOR_GL_POLYGON )
        view.drawing_color = CLR_PREVIEW_FILL
        view.draw( GL_QUADS, [ pts[0], pts[3], pts[15], pts[12] ] )
      end
      # Grid
      view.drawing_color = CLR_PREVIEW_BORDER
      # Border
      view.line_width = 2
      view.line_stipple = ''
      view.draw( GL_LINE_LOOP, [ pts[0], pts[3], pts[15], pts[12] ] )
      # Gridlines
      view.line_width = 1
      view.line_stipple = '-'
      view.draw( GL_LINES, [
        pts[1], pts[13],
        pts[2], pts[14],
        pts[4], pts[7],
        pts[8], pts[11]
      ] )
    end
    
    def onSetCursor
      UI.set_cursor( @cursor )
    end
    
    # Returns nil when input points are invalid.
    #
    # @since 1.0.0
    def control_points
      points = corner_points()
      return nil unless points
      interpolate_points( points )
    end
    
    # Returns nil when input points are invalid.
    #
    # @since 1.0.0
    def corner_points
      # Get corner points. Make points origin in @ip_start
      #
      # p1o  - ORIGIN
      # p2x  - X direction
      # p3y  - Y direction
      # p4xy - Opposite Corner
      #
      # p3 p4
      # p1 p2
      p1o = @ip_start.position
      return nil unless p1o
      p4xy = @ip_mouse.position
      if p1o.z == p4xy.z
        # Mesh is drawn planar to the ground.
        p2x = p1o.project_to_line( [ p4xy, Y_AXIS ] )
        p3y = p1o.project_to_line( [ p4xy, X_AXIS ] )
        return nil unless p2x && p3y
      else
        # Mesh is drawn vertically.
        p2x = p1o.project_to_line( [ p4xy, Z_AXIS ] )
        direction = p1o.vector_to( p2x )
        if direction.valid?
          p3y = p1o.project_to_line( [ p4xy, direction ] )
        else
          # In case the picked point is directly above the startpoint.
          # This scenario is not valid for creating a mesh.
          return nil
        end
      end
      [p1o, p2x, p3y, p4xy]
    end
    
    # @since 1.0.0
    def interpolate_points( points )
      p1o, p2x, p3y, p4xy = points
      # Y axis
      y1 = TT::Geom3d.interpolate_linear( p1o, p3y, 3 )
      y2 = TT::Geom3d.interpolate_linear( p2x, p4xy, 3 )
      # X axis
      pts = []
      y1.each_with_index { |start, i|
        row = TT::Geom3d.interpolate_linear( start, y2[i], 3 )
        pts.concat( row )
      }
      pts
    end
    
  end # class CreatePatchTool

end # module