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
    
    # Returns the control points for this BezierPatch.
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points
      @points
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
      for edge in self.edges
        picked << edge if ph.pick_segment( edge.segment(subdivs) , x, y )
      end
      #( picked.empty? ) ? nil : picked
      picked
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
  
  
  # Collection of methods for managing the bezier patch edges and their
  # relationship to connected entities.
  #
  # @since 1.0.0
  class BezierEdge
    
    attr_accessor( :control_points, :patches )
    
    # @param [Array<Geom::Point3d>] control_points Bezier control points
    #
    # @since 1.0.0
    def initialize( control_points )
      # (?) Require parent patch?
      # (!) Validate
      @control_points = control_points
      @patches = []
    end
    
    # Assosiates an entity with the current BezierEdge. Use to keep track of
    # which entities use this edge.
    #
    # @param [BezierPatch] entity
    #
    # @return [Nil]
    # @since 1.0.0
    def link( entity )
      if entity.is_a?( BezierPatch )
        if @patches.include?( entity )
          raise ArgumentError, 'Entity already linked.'
        else
          @patches << entity
        end
      else
        raise ArgumentError, "Can't link BezierEdge with #{entity.class}. Invalid entity type."
      end
      nil
    end
    
    # De-assosiates an entity.
    #
    # @param [BezierPatch] entity
    #
    # @return [Nil]
    # @since 1.0.0
    def unlink( entity )
      if entity.is_a?( BezierPatch )
        if @patches.include?( entity )
          @patches.delete( entity )
        else
          raise ArgumentError, 'Entity not linked.'
        end
      else
        raise ArgumentError, "Can't unlink BezierEdge with #{entity.class}. Invalid entity type."
      end
      nil
    end
    
    # Returns an array of 3d points representing the bezier curve with the given
    # sub-division.
    #
    # @param [Integer] subdivs
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def segment( subdivs )
      TT::Geom3d::Bezier.points( @control_points, subdivs )
    end
    
    # Returns an array of 3d points representing control points.
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def to_a
      @control_points.dup
    end
    
  end
  

end # module