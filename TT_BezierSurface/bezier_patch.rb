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
    attr_accessor( :reversed ) # (!) Not currently implemented!
    attr_accessor( :edgeuses, :interior_points )
    
    def initialize( *args )
      @parent = args[0] # BezierSurface
      @reversed = false
      @edgeuses = []
    end
    
    # Subclasses must implement these methods:
    #
    # def typename
    # def def add_to_mesh( pm, subdiv, transformation )
    # def mesh_points( subdiv, transformation )
    # def count_mesh_points( subdiv )
    # def count_mesh_polygons( subdiv )
    # def control_points
    # def edges
    # def get_control_grid_interior( points )
    # def draw_control_grid( points )
    # def draw_internal_grid( points )
    # def self.restore( surface, edgeuses, interior_points, reversed )
    
    # Replace an edge object with another.
    #
    # @param [BezierEdge] old_edge
    # @param [BezierEdge] new_edge
    #
    # @return [BezierEdge]
    # @since 1.0.0
    def set_edge( old_edge, new_edge )
      # Ensure the old edge belongs to this patch.
      unless old_edge.used_by?( self )
        raise ArgumentError, 'Edge not related to Patch.'
      end
      
      edgeuse = get_edgeuse( old_edge )
      edgeuse.edge = new_edge
      
      # (!) Hack - Find a method that works even if the points are not at
      # the same location. Or require points to be the same?
      TT.debug( 'BezierPatch.set_edge' )
      #TT.debug( "> #{old_edge.start == new_edge.start}" )
      #TT.debug( "> #{old_edge.start == new_edge.end}" )
      if old_edge.start == new_edge.end
        TT.debug( '> Reversed!' )
        edgeuse.reversed = !edgeuse.reversed?
      end
      
      # (!) Update control points of connected edges.
      
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
      for pt in control_points()
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
      for edge in edges()
        segment = edge.segment( subdivs, tr )
        picked << edge if ph.pick_segment( segment, x, y )
      end
      #( picked.empty? ) ? nil : picked
      picked
    end
    
    # @param [BezierEdge] edge
    #
    # @return [Integer]
    # @since 1.0.0
    def edge_index( edge )
      edgeuses.each_with_index { |edgeuse, index|
        return index if edge == edgeuse.edge
      }
      raise ArgumentError, 'Edge not connected to this patch.'
    end
    
    # @param [BezierEdge] edge
    #
    # @return [BezierEdgeUse]
    # @since 1.0.0
    def get_edgeuse( edge )
      edgeuses.each_with_index { |edgeuse, index|
        return edgeuse if edgeuse.edge == edge
      }
      raise ArgumentError, 'Edge not connected to this patch.'
    end
    
    # Draws the patch's control grid.
    #
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_internal_control_grid( view )
      cpoints = control_points()
      # Transform to active model space
      tr = view.model.edit_transform
      pts = cpoints.map { |pt|
        view.screen_coords( pt.transform(tr) )
      }
      # These methods needs to be implemented by the Patch subclass.
      interior = get_control_grid_interior( pts )
      for segment in interior
        view.draw2d( GL_LINE_STRIP, segment )
      end
      nil
    end
    
  end # module BezierPatch  

end # module