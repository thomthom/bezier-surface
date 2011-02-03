#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::BPatch
  
  class CreatePatchTool
    
    def initialize
      @ip_start = Sketchup::InputPoint.new			
			@ip_mouse = Sketchup::InputPoint.new
      @subdivs = 6
    end
    
    def update_ui
      if @ip_start.valid?
        Sketchup.status_text = 'Pick Opposite Corner.'
      else
        Sketchup.status_text = 'Pick Start Point.'
      end
    end
    
    def activate
      update_ui()
    end
    
    def deactivate(view)
      view.invalidate
    end
    
    def resume(view)
      view.invalidate
      update_ui()
    end
    
    def onUserText(text, view)
      subd = text.to_i
      @subdivs = subd
    end
    
    def onMouseMove(flags, x, y, view)
      view.invalidate if @ip_mouse.pick(view, x, y)
    end
    
    def onLButtonUp(flags, x, y, view)
      if @ip_start.valid?
        # Create Patch
        TT::Model.start_operation('Create Bezier Surface')
        g = view.model.active_entities.add_group
        g.name = 'Bezier Surface'
        g.transform!( Geom::Transformation.new(@ip_start.position) )
        points = control_points()
        patch = QuadPatch.new( points )
        surface = BezierSurface.new( g )
        surface.add_patch( patch )
        surface.update( view.model.edit_transform )
        view.model.commit_operation
        view.model.selection.clear
        view.model.selection.add( g )
        # End tool
        view.model.tools.pop_tool
        # Activate Edit Tool
        #tool = EditPatchTool.new( g )
        #view.model.tools.push_tool( tool )
      else
        @ip_start.copy!(@ip_mouse)
        #view.lock_inference(@ip_start) unless @ip_start.face.nil?
        update_ui()
      end
    end
    
    def draw(view)
      # InputPoints
      @ip_start.draw(view) if @ip_start.valid?
      @ip_mouse.draw(view) if @ip_mouse.valid?
      # Mesh Control Points
      return unless @ip_start.valid? && @ip_mouse.valid?
      o = @ip_start.position
      pts = control_points().map { |pt|
        pt.transform( o )
      }
      # ...
      view.drawing_color = 'purple'
      # Border
      view.line_width = 2
      view.line_stipple = ''
      view.draw( GL_LINE_LOOP, [ pts[0], pts[3], pts[15], pts[12] ] )
      # Gridlines
      view.line_width = 1
      view.line_stipple = '.'
      view.draw( GL_LINES, [
        pts[1], pts[13],
        pts[2], pts[14],
        pts[4], pts[7],
        pts[8], pts[11]
      ] )
    end
    
    def control_points
      # Get corner points. Make points origin in @ip_start
      p1 = ORIGIN
      v = @ip_mouse.position - @ip_start.position
      t = Geom::Transformation.new( @ip_start.position ).inverse
      p2 = @ip_mouse.position.transform( t )
      if p1.z == p2.z
        p3 = p1.project_to_line( [ p2, Y_AXIS ] )
        p4 = p1.project_to_line( [ p2, X_AXIS ] )
      else
        p3 = p1.project_to_line( [ p2, Z_AXIS ] )
        v = p1.vector_to( p3 )
        p4 = p1.project_to_line( [ p2, v ] )
      end
      # Y axis
      y1 = TT::Geom3d.interpolate_linear( p1, p4, 3 )
      y2 = TT::Geom3d.interpolate_linear( p3, p2, 3 )
      #y1 = TT::Geom3d.interpolate_linear( p4, p1, 3 )
      #y2 = TT::Geom3d.interpolate_linear( p2, p3, 3 )
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