
module TT::Plugins::BPatch

  class BezierSurfaceEditor    
    
    attr_reader( :model, :surface, :selection )
    
    def initialize( model )
      @model = model
      @selection = Selection.new
      @surface = nil
      
      @active_tool = nil
      @active = false
      
      @model_observer = BP_Editor_ModelObserver.new
    end
    
    def edit( instance )
      TT.debug( 'BezierSurfaceEditor.edit' )
      @model.tools.push_tool( self )
      @surface = BezierSurface.load( instance )
      tool = VertexSelectionTool.new( self )
      select_tool( tool )
    end
    
    def select_tool( tool )
      TT.debug( 'BezierSurfaceEditor.select_tool' )
      @model.tools.pop_tool if @active_tool
      @active_tool = tool
      @model.tools.push_tool( tool )
    end
    
    def end_session
      TT.debug( 'BezierSurfaceEditor.end_session' )
      if @active
        TT.debug( '> Ending active...' )
        @model.tools.pop_tool if @active_tool
        @model.tools.pop_tool
      end
    end
    
    def change_subdivisions( subdivs )
      if subdivs > 0
        @model.start_operation('Change Subdivisions', true)
        @surface.subdivs = subdivs
        @surface.update( @model.edit_transform )
        @model.commit_operation
        true
      else
        false
      end
    end
    
    def transform_selection( transformation )
      @model.start_operation('Edit Bezier Surface', true)
      for point in @selection
        point.transform!( transformation )
      end
      @surface.update( @model.edit_transform )
      @model.commit_operation
    end
    
    def move_selection( vector )
      if vector.valid? && @selection.size > 0
        t = Geom::Transformation.new( vector )
        transform_selection( t )
        true
      else
        false
      end
    end
    
    def valid_context?
      (@model.active_path.nil?) ? false : @model.active_path.last == @surface.instance
    end
    
    # Called by the BP_Editor_ModelObserver observer
    def undo_redo
      TT.debug( 'BezierSurfaceEditor.undo_redo' )
      if valid_context?
        @surface.reload
        @selection.clear
      else
        TT.debug( '> Invalid Context' )
        self.end_session
      end
    end
    
    # Draw mesh grids and control points
    def draw( view, preview = false )
      t = view.model.edit_transform
      # Control Grid
      @surface.draw_grid( view, preview )
      @surface.draw_control_grid( view )
      # Points
      view.line_stipple = ''
      view.line_width = 2
      pts = @surface.control_points.map { |pt| pt.transform(t) }
      view.draw_points( pts, VERTEX_SIZE, TT::POINT_OPEN_SQUARE, CLR_VERTEX )
      # Selection
      unless @selection.empty?
        pts = @selection.map { |pt| pt.transform(t) }
        view.draw_points( pts, VERTEX_SIZE, TT::POINT_FILLED_SQUARE, CLR_VERTEX )
      end
      # Account for SU bug where draw_points kills the next draw operation.
      view.draw2d( GL_LINES, [-10,-10,-10], [-11,-11,-11] )
    end
    
    def inspect
      "#<#{self.class}:#{self.object_id}>"
    end
    
    def show_toolbar
      if @toolbar.nil?
        path = File.join( TT::Plugins::BPatch::PATH, 'UI')
        options = {
          :title => 'Bezier Surface',
          :pref_key => "#{TT::Plugins::BPatch::ID}_Toolbar",
          :left => 200,
          :top => 200,
          :width => 250,
          :height => 50,
          :resizable => false,
          :scrollable => false
        }
        @toolbar = TT::GUI::ToolWindow.new( options )
        @toolbar.add_script( File.join(path, 'js', 'wnd_toolbar.js') )
        @toolbar.add_style( File.join(path, 'css', 'wnd_toolbar.css') )
      end
      @toolbar.show_window
    end
    
    def close_toolbar
      @toolbar.close if @toolbar.visible?
    end
    
    ### Tool Events
    
    def activate
      TT.debug( 'BezierSurfaceEditor.activate' )
      @active = true
      @active_tool = nil
      @selection.clear
      
      # UI
      show_toolbar()
      
      TT.debug( @model.add_observer( @model_observer ) )
    end
    
    def deactivate(view)
      TT.debug( 'BezierSurfaceEditor.deactivate' )
      @active = false
      @active_tool = nil
      
      close_toolbar()
      
      # (!) SketchUp bug!
      # Normally, closing a group/component appears on the undo stack.
      # But when this method is used in SU8-M0 and older the action does not
      # appear in the stack - and when you then trigger and undo after using
      # this method all the modified geometry is offset.
      model.close_active
      
      TT.debug( @model.remove_observer( @model_observer ) )
    end
    
  end # class BezierSurfaceEditor
  
end # module TT::Plugins::BPatch