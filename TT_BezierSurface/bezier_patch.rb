#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # Mix-in module with core methods used and required by all types of patches.
  #
  # @example
  #  class QuadPatch
  #    include BezierPatch
  #    # ...
  #  end
  #
  # @since 1.0.0
  module BezierPatch
    
    attr_reader( :parent )
    attr_accessor( :reversed )
    
    def initialize( *args )
      @parent = args[0] # BezierSurface
      @reversed = false
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
    # def edge_reversed?( bezier_edge )
    
    # Returns the control points for this BezierPatch.
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points
      @points
    end
    
    # Replace an edge object with another.
    #
    # @param [BezierEdge] old_edge
    # @param [BezierEdge] new_edge
    #
    # @return [BezierEdge]
    # @since 1.0.0
    def set_edge( old_edge, new_edge )
      # Ensure the old edge belongs to this patch.
      unless @edges.include?( old_edge )
        raise ArgumentError, 'Edge not related to Patch.'
      end
      
      # (!) Update control points.
      
      index = edge_index( old_edge )
      @edges[ index ] = new_edge
      new_edge
    end
    
    # Pick-tests the patch with the given screen co-ordinates. Returns an array
    # of picked points.
    #
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def pick_control_points( x, y, view )
      # (?) Return only one point?
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
    
    # (!) Move to BezierEdge
    #
    # Pick-tests the patch's edges with the given sub-division.  Returns an array
    # of picked +BezierEdge+ objects.
    #
    # @param [Integer] subdivs
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def pick_edges( subdivs, x, y, view )
      # (?) Return only one entity?
      picked = []
      ph = view.pick_helper( x, y )
      tr = view.model.edit_transform
      for edge in self.edges
        segment = edge.segment( subdivs, tr )
        picked << edge if ph.pick_segment( segment, x, y )
      end
      #( picked.empty? ) ? nil : picked
      picked
    end
    
    # (!) private? BezierPatchLoop?
    #
    # @param [BezierEdge] edge
    #
    # @return [BezierEdge]
    # @since 1.0.0
    def next_edge( edge )
      index = edge_index( edge )
      array_index = ( index + 1 ) % @edges.size
      @edges[ array_index ]
    end
    
    # (!) private? BezierPatchLoop?
    #
    # @param [BezierEdge] edge
    #
    # @return [BezierEdge]
    # @since 1.0.0
    def prev_edge( edge )
      index = edge_index( edge )
      array_index = ( index - 1 ) % @edges.size
      @edges[ array_index ]
    end
    
    # (!) private? BezierPatchLoop?
    #
    # @param [BezierEdge] edge
    #
    # @return [Boolean]
    # @since 1.0.0
    def edge_index( edge )
      @edges.each_with_index { |e, index|
        return index if edge == e
      }
      raise ArgumentError, 'Edge not connected to this patch.'
    end
    
    # Draws the patch's control grid.
    #
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_control_grid( view )
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
        quads = pts3d.to_a.values_at(
           0, 1, 5, 4,
           1, 2, 6, 5,
           2, 3, 7, 6,
           
           4, 5, 9, 8,
           5, 6,10, 9,
           6, 7,11,10,
           
           8, 9,13,12,
           9,10,14,13,
          10,11,15,14
        )
        
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
      nil
    end
    
    # Draws the patch's internal grid with the given sub-division.
    #
    # @param [Integer] subdivs
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_grid( subdivs, view )
      # (!) This is spesific to quad patches. Move to QuadPatch class or
      # abstract if possible.
      
      # Transform to active model space
      t = view.model.edit_transform
      pts = mesh_points( subdivs, t )
      
      if pts.size > 2
        # Set up viewport
        view.drawing_color = CLR_MESH_GRID
        # Meshgrid
        view.line_width = MESH_GRID_LINE_WIDTH
        view.line_stipple = ''
        pts.rows[1...pts.width-1].each { |row|
        #pts.each_row { |row|
          view.draw( GL_LINE_STRIP, row )
        }
        pts.columns[1...pts.height-1].each { |col|
        #pts.each_column { |col|
          view.draw( GL_LINE_STRIP, col )
        }
      end
    end
    
  end # module BezierPatch  

end # module