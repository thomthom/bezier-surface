#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::BPatch
  
  class EditPatchTool
    
    def initialize( instance )
      @surface = BezierSurface.load( instance )
      @selected = []
      
      @ip_start = Sketchup::InputPoint.new			
			@ip_mouse = Sketchup::InputPoint.new
      @drag = false
    end
    
    def update
      Sketchup.status_text = 'Click a control point to select it. Drag to move it.'
      Sketchup.vcb_label = 'Subdivisions'
      Sketchup.vcb_value = @surface.subdivs
    end
    
    def activate
      Sketchup.active_model.selection.clear
      update()
    end
    
    def deactivate(view)
      Sketchup.active_model.selection.add( @surface.instance )
      view.invalidate
    end
    
    def resume(view)
      view.invalidate
      update()
    end
    
    def onUserText(text, view)
      subd = text.to_i
      @surface.subdivs = subd
      TT::Model.start_operation('Change Subdivisions')
      @surface.update
      view.model.commit_operation
      update()
    end
    
    def onCancel(reason, view)
      puts 'onCancel'
      case reason
      when 0 # ESC
        puts '> ESC'
        @ip_start.clear			
        @ip_mouse.clear
        @drag = false
        view.invalidate
      when 1 # Reactivate Tool
        puts '> Reactivate'
      when 2 # Undo
        puts '> Undo'
        @surface.reload
        @ip_start.clear			
        @ip_mouse.clear
        @drag = false
        view.invalidate
      end
    end
    
    def onMouseMove(flags, x, y, view)
      @ip_mouse.pick(view, x, y)
      if flags & MK_LBUTTON == MK_LBUTTON
        @drag = true
      end
      view.invalidate #if @ip_mouse.pick(view, x, y)
    end
    
    def onLButtonDown(flags, x, y, view)
      @ip_start.copy!(@ip_mouse)
    end
    
    def onLButtonUp(flags, x, y, view)
      if @drag && @ip_start.valid? && @ip_mouse.valid?
        v = @ip_start.position.vector_to( @ip_mouse.position )
        t = Geom::Transformation.new( v )
        TT::Model.start_operation('Edit Bezier Surface')
        if v.valid?
          @selected.each { |pt|
            pt.transform!( t )
          }
        end
        @surface.update
        view.model.commit_operation
      end
      
      @ip_start.clear			
			@ip_mouse.clear
      @drag = false
      
      
      ph = view.pick_helper
      ph.init(x, y, 10)
      t = @surface.instance.transformation
      for pt in @surface.points
        if ph.test_point( pt.transform(t) )
          if @selected.include?( pt )
            @selected.delete( pt )
          else
            @selected << pt
          end
        end
      end
      view.invalidate
    end
    
    def draw(view)
      @ip_start.draw(view) if @ip_start.valid?
      @ip_mouse.draw(view) if @ip_mouse.valid?
      
      if @ip_start.valid? && @ip_mouse.valid?
        view.drawing_color = 'orange'
        view.line_stipple = ''
        view.line_width = 2
        view.draw( GL_LINES, @ip_start.position, @ip_mouse.position )
      end
      
      t = @surface.instance.transformation
      # Control Grid
      @surface.draw_grid(view)
      @surface.draw_control_grid(view)
      # Points
      view.line_stipple = ''
      view.line_width = 2
      pts = @surface.points.map { |pt| pt.transform(t) }
      view.draw_points( pts, 10, 1, 'red' )
      # Selection
      unless @selected.empty?
        pts = @selected.map { |pt| pt.transform(t) }
        view.draw_points( pts, 10, 2, 'red' )
      end
    end

    
  end # class CreatePatchTool

end # module