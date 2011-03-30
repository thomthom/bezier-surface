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
      tr = view.model.edit_transform
      for edge in self.edges
        segment = edge.segment( subdivs, tr )
        picked << edge if ph.pick_segment( segment, x, y )
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
    
    # @return [QuadPatch]
    # @since 1.0.0
    def extrude_quad_patch
      if self.patches.size > 1
        raise ArgumentError, 'Can not extrude edge connected to more than one patch.'
      end
      
      patch = self.patches[0]
      surface = patch.parent
      edge_reversed = self.reversed_in?( patch )
      
      # <debug>
      index = patch.edge_index( self )
      TT.debug( "Extrude Edge: (#{index}) #{self}" )
      TT.debug( "> Length: #{self.length(surface.subdivs).to_s}" )
      TT.debug( "> Reversed: #{edge_reversed}" )
      # </debug>
      
      # Use the connected edges to determine the direction of the extruded
      # bezier patch.
      prev_edge = patch.prev_edge( self )
      next_edge = patch.next_edge( self )
      
      # <debug>
      TT.debug( "> Prev Edge: #{prev_edge}" )
      TT.debug( "> Next Edge: #{next_edge}" )
      # </debug>
      
      # Cache the point for quicker access.
      pts = self.control_points
      pts_prev = prev_edge.control_points
      pts_next = next_edge.control_points
      
      # Sort the points in a continuous predictable order.
      pts.reverse! if edge_reversed
      pts_prev.reverse! if prev_edge.reversed_in?( patch )
      pts_next.reverse! if next_edge.reversed_in?( patch )
      
      # Calculate the extrusion direction for the control points in the new patch.
      v1 = pts_prev[3].vector_to( pts_prev[2] ).reverse
      v2 = pts_next[0].vector_to( pts_next[1] ).reverse
      
      # (!) Unfinished - this is a quick hack. Need better Bezier Entity control
      # first.
      # The start and end control point vectors is used for the interior points.
      # In the finished product the interior points should be derived from
      # related interior points from the source patch in order to provide
      # a continous surface.
      directions = [ v1, v1, v2, v2 ]

      # Extrude the new patch by the same length as the edge it's extruded from.
      # This should be an ok length that scales predictably in most conditions.
      length = self.length( surface.subdivs ) / 3
      
      # Generate the control points for the new patch.
      points = []
      pts.each_with_index { |point, index|
        points << point.clone
        points << point.offset( directions[index], length )
        points << point.offset( directions[index], length * 2 )
        points << point.offset( directions[index], length * 3 )
      }
      
      # Create the BezierPatch entity, add all entity assosiations.
      new_patch = QuadPatch.new( surface, points )
      new_patch.reversed = true if patch.reversed
      self.link( new_patch )
      # (!) merge edges
      
      # Add the patch to the surface and regenerate the mesh.
      model = Sketchup.active_model
      model.start_operation('Add Quad Patch', true)
      surface.add_patch( new_patch )
      surface.update( model.edit_transform )
      model.commit_operation
      
      new_patch
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
    def segment( subdivs, transformation = nil )
      points = TT::Geom3d::Bezier.points( @control_points, subdivs )
      if transformation
        points.map! { |point| point.transform!( transformation ) }
      end
      points
    end
    
    # @param [BezierPatch] subdivs
    #
    # @return [Boolean]
    # @since 1.0.0
    def reversed_in?( patch )
      patch.edge_reversed?( self )
    end
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def direction
      p1 = @control_points.first
      p2 = @control_points.last
      p1.vector_to( p2 )
    end
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def start
      @control_points.first#.extend( TT::Point3d_Ex )
    end
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def end
      @control_points.last#.extend( TT::Point3d_Ex )
    end
    
    # @return [Length]
    # @since 1.0.0
    def length( subdivs )
      total = 0.0
      points = segment( subdivs )
      for index in (0...points.size-1)
        pt1 = points[index]
        pt2 = points[index+1]
        total += pt1.distance( pt2 )
      end
      total.to_l
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