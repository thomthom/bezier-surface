#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @abstract Mix-in module with core methods used and required by all types of
  #   patches.
  #
  # @example
  #  class QuadPatch < BezierEntity
  #    include BezierPatch
  #    # ...
  #  end
  #
  # @since 1.0.0
  module BezierPatch
    
    attr_accessor( :edgeuses, :interior_points )
    
    def initialize( parent, points )
      #TT.debug 'BezierPatch.new'
      
      super()
      
      TT::Point3d.extend_all( points )
      
      @parent = parent # BezierSurface
      @automatic = true
      @edgeuses = []
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def automatic?
      fail_if_invalid()
      @automatic ==  true
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def automatic=( is_automatic )
      fail_if_invalid()
      @automatic = ( is_automatic == true )
    end
    
    # Returns an array of +BezierEdge+ objects in clock-wise order.
    #
    # @return [Array<BezierEdge>]
    # @since 1.0.0
    def edges
      fail_if_invalid()
      @edgeuses.map { |edgeuse| edgeuse.edge }
    end
    
    # @return [Array<BezierHandle>]
    # @since 1.0.0
    def handles
      fail_if_invalid()
      result = edges.map { |e| e.handles }
      result.flatten!
      result.uniq!
      result
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
      fail_if_invalid()
      # Ensure the old edge belongs to this patch.
      unless old_edge.links_to?( self )
        raise ArgumentError, 'Edge not related to Patch.'
      end
      
      TT.debug( 'BezierPatch.set_edge' )
      TT.debug "Old: #{old_edge}"
      TT.debug "New: #{old_edge}"
      
      edgeuse = get_edgeuse( old_edge )
      edgeuse.edge = new_edge
      
      # Associate the new edge with this patch.
      #for point in new_edge.control_points
      #  point.link( self )
      #end
      
      # (?) Required?
      # Remove association between the old edge and the control points.
      for point in old_edge.control_points
        point.unlink( old_edge )
        #point.link( new_edge )
      end
      
      # (!) Hack - Find a method that works even if the points are not at
      # the same location. Or require points to be the same?
      #TT.debug( 'BezierPatch.set_edge' )
      #TT.debug( "> #{old_edge.start == new_edge.start}" )
      #TT.debug( "> #{old_edge.start == new_edge.end}" )
      if old_edge.start.position == new_edge.end.position
        TT.debug( '> Reversed!' )
        edgeuse.reversed = !edgeuse.reversed?
        
        new_start = new_edge.end
        new_end = new_edge.start
      else
        new_start = new_edge.start
        new_end = new_edge.end
      end
      
      # (!) Update control points of connected edges.
      # Update the vertices of self with the vertices of the new edge.
      
      old_start = old_edge.start
      for edge in old_start.edges
        next if edge == old_edge
        if edge.start == old_start
          edge.start = new_start
        else 
          edge.end = new_start
        end
      end
      
      old_end = old_edge.end
      for edge in old_end.edges
        next if edge == old_edge
        if edge.end == old_end
          edge.end = new_end
        else 
          edge.start = new_end
        end
      end
      
      new_edge.link( self )
      for point in new_edge.control_points
        point.link( self )
      end
      
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
      fail_if_invalid()
      # (?) Return only one point?
      picked = []
      t = view.model.edit_transform
      aperture = VERTEX_SIZE * 2
      ph = view.pick_helper( x, y, aperture )
      ph.init( x, y, aperture )
      for cpt in control_points()
        picked << cpt if ph.test_point( cpt.position.transform(t) )
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
      fail_if_invalid()
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
      fail_if_invalid()
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
      fail_if_invalid()
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
      fail_if_invalid()
      cpoints = positions()
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