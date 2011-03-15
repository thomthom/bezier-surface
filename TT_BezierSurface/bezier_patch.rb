#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  module BezierPatch
    
    def initialize( *args )
      #...
    end
    
    # Subclasses must implement these methods:
    #
    # def typename
    # def def add_to_mesh( pm, subdiv, transformation )
    # def mesh_points( subdiv, transformation )
    # def count_mesh_points( subdiv )
    # def count_mesh_polygons( subdiv )
    # def edges
    # def get_control_grid_border( points )
    # def get_control_grid_interior( points )
        
    def control_points
      @points
    end

    def pick_control_points(x, y, view)
      picked = []
      t = view.model.edit_transform
      aperture = VERTEX_SIZE * 2
      ph = view.pick_helper( x, y, aperture )
      ph.init( x, y, aperture )
      for pt in @points
        picked << pt if ph.test_point( pt.transform(t) )
      end
      #( picked.empty? ) ? nil : picked
      picked
    end
    
    def pick_edges(subdivs, x, y, view)
      picked = []
      ph = view.pick_helper( x, y )
      for edge in self.edges
        picked << edge if ph.pick_segment( edge.segment(subdivs) , x, y )
      end
      #( picked.empty? ) ? nil : picked
      picked
    end
    
    def draw_control_grid(view)
      # Transform to active model space
      t = view.model.edit_transform
      pts = @points.map { |pt|
        view.screen_coords( pt.transform(t) )
      }
      # These methods needs to be implemented by the Patch subclass.
      border    = get_control_grid_border( pts )
      interior  = get_control_grid_interior( pts )
      # Fill colour
      if TT::SketchUp.support?( TT::SketchUp::COLOR_GL_POLYGON )
        fill = TT::Color.clone( CLR_CTRL_GRID )
        fill.alpha = 32
        view.drawing_color = fill
        
        pts3d = @points.map { |pt| pt.transform(t) }
        quads = []
        
        quads.concat( [ pts3d[0], pts3d[1], pts3d[5], pts3d[4] ] )
        quads.concat( [ pts3d[1], pts3d[2], pts3d[6], pts3d[5] ] )
        quads.concat( [ pts3d[2], pts3d[3], pts3d[7], pts3d[6] ] )
        
        quads.concat( [ pts3d[4], pts3d[5], pts3d[9], pts3d[8] ] )
        quads.concat( [ pts3d[5], pts3d[6], pts3d[10], pts3d[9] ] )
        quads.concat( [ pts3d[6], pts3d[7], pts3d[11], pts3d[10] ] )
        
        quads.concat( [ pts3d[8], pts3d[9], pts3d[13], pts3d[12] ] )
        quads.concat( [ pts3d[9], pts3d[10], pts3d[14], pts3d[13] ] )
        quads.concat( [ pts3d[10], pts3d[11], pts3d[15], pts3d[14] ] )
        
        view.draw( GL_QUADS, quads )
      end
      # Set up viewport
      view.drawing_color = CLR_CTRL_GRID
      # Border
      view.line_width = CTRL_GRID_BORDER_WIDTH
      view.line_stipple = ''
      for segment in border
        view.draw2d( GL_LINE_STRIP, segment )
      end
      # Gridlines
      view.line_width = CTRL_GRID_LINE_WIDTH
      view.line_stipple = '-'
      for segment in interior
        view.draw2d( GL_LINE_STRIP, segment )
      end
    end
    
    def draw_grid(subdivs, view)
      # Transform to active model space
      t = view.model.edit_transform
      pts = mesh_points( subdivs, t )
      # Set up viewport
      view.drawing_color = CLR_MESH_GRID
      # Meshgrid
      view.line_width = MESH_GRID_LINE_WIDTH
      view.line_stipple = ''
      pts.each_row { |row|
        view.draw( GL_LINE_STRIP, row )
      }
      pts.each_column { |col|
        view.draw( GL_LINE_STRIP, col )
      }
    end
    
  end # module BezierPatch
  
  
  class BezierEdge
    
    attr_accessor( :control_points, :patches )
    
    def initialize( control_points )
      # (!) Validate
      @control_points = control_points
      @patches = []
    end
    
    def segment( subdivs )
      TT::Geom3d::Bezier.points( @control_points, subdivs )
    end
    
    def to_a
      @control_points.dup
    end
    
  end
  

end # module