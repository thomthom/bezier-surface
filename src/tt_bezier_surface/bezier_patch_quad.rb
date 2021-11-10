#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # Manages bezier quad-patches.
  #
  # @since 1.0.0
  class QuadPatch < BezierEntity
    include BezierPatch

    # @param [Array<Geom::Point3d>] points Bezier control points
    #
    # @since 1.0.0
    def initialize( parent, points )
      Console.log 'QuadPatch.new'

      # Validate arguments
      raise ArgumentError, 'points not an Array.' unless points.is_a?(Array)
      raise ArgumentError, 'points must have 16 Point3d' unless points.size == 16
      unless points.all? { |point|
        point.is_a?( Geom::Point3d )
      }
        raise ArgumentError, 'points must be Point3d objects.'
      end

      # Init superclass. (Extends points into Point3d_Ex.)
      super

      # Create control points and assosiate them with this patch.
      #
      # 12--13--14--15
      # |   |   |   |
      # 8---9---10--11
      # |   |   |   |
      # 4---5---6---7
      # |   |   |   |
      # 0---1---2---3
      #
      grid = TT::Dimension.new( [
        BezierVertex.new( parent, points[0] ),
        BezierHandle.new( parent, points[1] ),
        BezierHandle.new( parent, points[2] ),
        BezierVertex.new( parent, points[3] ),

        BezierHandle.new( parent, points[4] ),
        BezierInteriorPoint.new( parent, points[5] ),
        BezierInteriorPoint.new( parent, points[6] ),
        BezierHandle.new( parent, points[7] ),

        BezierHandle.new( parent, points[8] ),
        BezierInteriorPoint.new( parent, points[9] ),
        BezierInteriorPoint.new( parent, points[10] ),
        BezierHandle.new( parent, points[11] ),

        BezierVertex.new( parent, points[12] ),
        BezierHandle.new( parent, points[13] ),
        BezierHandle.new( parent, points[14] ),
        BezierVertex.new( parent, points[15] )
      ], 4, 4 )
      # Link Control Points to the patch.
      for control_point in grid
        control_point.link( self )
      end
      # Link Vertices to Interior Points.
      grid[ 0].link( grid[ 5] )
      grid[ 3].link( grid[ 6] )
      grid[12].link( grid[ 9] )
      grid[15].link( grid[10] )
      # Link Interior Points to Vertices.
      # (!) Redundant when .link back-references?
      grid[ 5].link( grid[ 0] )
      grid[ 6].link( grid[ 3] )
      grid[ 9].link( grid[12] )
      grid[10].link( grid[15] )

      interiorpoints = [ grid[5], grid[6], grid[9], grid[10] ]
      @interior_points = TT::Dimension.new( interiorpoints, 2, 2 )

      # Create edges and assosiate them with this patch.
      # Order of edges and direction of their control points.
      #
      #  Y - Columns
      #
      #  ^
      #  |
      #
      #  x --> X - Rows
      #
      # +--->---+
      # |   2   |
      # ^3     1^
      # |   0   |
      # +--->---+
      #
      # Edge 2 and 3 is initially reversed.
      #
      # +---<---+
      # |   2   |
      # v3     1^
      # |   0   |
      # +--->---+
      #
      # Points are reversed to return edges that run in the same direction
      # around the patch.
      edge = BezierEdge.new( parent, grid.row(0) )
      edge.link( self )
      edgeuse = BezierEdgeUse.new( self, edge )
      @edgeuses << edgeuse

      edge = BezierEdge.new( parent, grid.column(3) )
      edge.link( self )
      edgeuse = BezierEdgeUse.new( self, edge )
      @edgeuses << edgeuse

      edge = BezierEdge.new( parent, grid.row(3).reverse )
      edge.link( self )
      edgeuse = BezierEdgeUse.new( self, edge )
      @edgeuses << edgeuse

      edge = BezierEdge.new( parent, grid.column(0).reverse )
      edge.link( self )
      edgeuse = BezierEdgeUse.new( self, edge )
      @edgeuses << edgeuse
    end

    # @return [QuadPatch]
    # @since 1.0.0
    def self.restore( surface, edgeuses, interior_points )
      Console.log 'QuadPatch.restore'
      # Validate
      unless surface.is_a?( BezierSurface )
        raise ArgumentError, 'Argument not a BezierSurface.'
      end
      unless edgeuses.size == 4
        raise ArgumentError, "Invalid number of EdgeUses (#{edgeuses.size})."
      end
      unless interior_points.size == 4
        raise ArgumentError, "Invalid number of interior points (#{interior_points.size})."
      end

      dummy_points = Array.new( 16, Geom::Point3d.new(0,0,0) )
      dummy_points[5]  = interior_points[0]
      dummy_points[6]  = interior_points[1]
      dummy_points[9]  = interior_points[2]
      dummy_points[10] = interior_points[3]
      patch = self.new( surface, dummy_points )
      patch.edgeuses.each_with_index { |edgeuse, index|
        prototype = edgeuses[ index ]
        edgeuse.edge = prototype.edge
        edgeuse.edge.link( patch )
        edgeuse.reversed = prototype.reversed?
      }
      # <temp>
      # edgeuse.edge= should correct this.
      for control_point in patch.control_points
        control_point.link( patch )
      end
      # </temp>
      patch
    end

    # Returns the control points for this BezierPatch.
    #
    # @example:
    #  12--13--14--15
    #  |   |   |   |
    #  8---9---10--11
    #  |   |   |   |
    #  4---5---6---7
    #  |   |   |   |
    #  0---1---2---3
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points
      fail_if_invalid()
      #
      # POINTS:
      #
      # 12--13--14--15
      # |   |   |   |
      # 8---9---10--11
      # |   |   |   |
      # 4---5---6---7
      # |   |   |   |
      # 0---1---2---3
      #
      # EDGES:
      #
      # X-----2-----X
      # |   |   |   |
      # |---X---X---|
      # 3   |   |   1
      # |---X---X---|
      # |   |   |   |
      # X-----0-----X
      #
      # INTERIOR POINTS:
      #
      # X---X---X---X
      # |   |   |   |
      # X---2---3---X
      # |   |   |   |
      # X---0---1---X
      # |   |   |   |
      # X---X---X---X
      #
      e0,e1,e2,e3 = ordered_edge_control_points()
      points = []
      # Row 1
      points.concat( e0 )
      # Row 2
      points << e3[2]
      points << @interior_points[0]
      points << @interior_points[1]
      points << e1[1]
      # Row 3
      points << e3[1]
      points << @interior_points[2]
      points << @interior_points[3]
      points << e1[2]
      # Row 4
      points.concat( e2.reverse )
      points
      TT::Dimension.new( points, 4, 4 )
    end

    # Returns an array of +BezierEdge+ objects in clock-wise order.
    #
    # @return [Array<BezierVertex>]
    # @since 1.0.0
    def vertices
      fail_if_invalid()
      edge1 = @edgeuses[0].edge
      edge2 = @edgeuses[2].edge
      v1 = edge1.vertices
      v2 = edge2.vertices
      v1.reverse! if edge1.reversed_in?( self )
      v2.reverse! if edge2.reversed_in?( self )
      v1 + v2.reverse
    end

    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def positions
      fail_if_invalid()
      control_points.map { |control_point|
        control_point.position
      }
    end

    # @return [Boolean]
    # @since 1.0.0
    def refresh_interior
      if automatic?
        @interior_points = interpolate_interior()
        true
      else
        false
      end
    end

    # Accurate calculation of the number of vertices in the mesh.
    #
    # @param [Integer] subdivs
    #
    # @return [Integer]
    # @since 1.0.0
    def count_mesh_points( subdiv )
      fail_if_invalid()
      ( subdiv + 1 ) * ( subdiv + 1 )
    end

    # Maximum number of polygons in a patch. If the patch tries to maintain
    # quad-faces when possible the actual number of polygons might be less.
    #
    # @param [Integer] subdivs
    #
    # @return [Integer]
    # @since 1.0.0
    def count_mesh_polygons( subdiv )
      fail_if_invalid()
      subdiv * subdiv * 2
    end

    # @note Slow performance. Improve!
    #
    # Returns a set of 3d points for this patch using the given sub-division.
    #
    # @param [Integer] subdivs
    # @param [Geom::Transformation] transformation World space transformation.
    #
    # @return [TT::Dimension]
    # @since 1.0.0
    def mesh_points( subdiv, transformation )
      fail_if_invalid()
      world_points = positions().map { |pt| pt.transform( transformation ) }
      size = subdiv + 1
      points = TT::Geom3d::Bezier.patch( world_points.to_a, subdiv )
      TT::Dimension.new( points, size, size )
    end

    # Draws the patch's internal grid with the given sub-division.
    #
    # @param [Integer] subdivs
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_internal_grid( subdivs, view )
      fail_if_invalid()
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
          view.draw( GL_LINE_STRIP, row )
        }
        pts.columns[1...pts.height-1].each { |col|
          view.draw( GL_LINE_STRIP, col )
        }
      end
    end

    # Draws the patch's control grid.
    #
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_control_grid_fill( view )
      fail_if_invalid()
      tr = view.model.edit_transform
      # Fill colour
      if TT::SketchUp.support?( TT::SketchUp::COLOR_GL_POLYGON )
        fill = TT::Color.clone( CLR_CTRL_GRID )
        fill.alpha = 32
        view.drawing_color = fill

        pts3d = positions().map { |pt| pt.transform(tr) }
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
      nil
    end

    # Assume a quadratic set of points
    #
    # Example using a 4x4 set of points:
    #  0  1  2  3
    #  4  5  6  7
    #  8  9 10 11
    # 12 13 14 15
    #
    # Take four points from the set:
    #
    #  0  1
    #  4  5
    #
    # Try to create a quadface if possible, ...
    #
    # 0--1
    # |  |
    # 4--5
    #
    # ... otherwise triangulate.
    #
    # 0--1    1
    # | /   / |
    # 4    4--5
    #
    # Continue to the next set...
    #
    #  1  2
    #  5  6
    #
    # ... and repeat.
    #
    # @param [Geom::PolygonMesh] mesh
    # @param [Integer] subdivs
    # @param [Geom::Transformation] transformation
    #
    # @return [Geom::PolygonMesh]
    # @since 1.0.0
    def add_to_mesh( mesh, subdiv, transformation )
      fail_if_invalid()
      triangulate = false # (?) Instance variable
      inversed = false

      pts = mesh_points( subdiv, transformation )

      # Increase speed by pre-populating the points that will be used and keep
      # a cache of the point indexes.
      point_index = []
      for pt in pts
        point_index << mesh.add_point( pt )
      end

      for y in (0...pts.height-1)
        for x in (0...pts.width-1)
          row = y * pts.width # Current row
          # Pick out the indexes from the patch 2D-matrix we're interested in.
          pos = [ x+row, x+1+row, x+pts.width+1+row, x+pts.width+row ]
          # Get the point indexes and mirror orientation
          indexes = pos.collect { |i| point_index[i] }
          indexes.reverse! if inversed

          next unless indexes.length > 2

          if indexes.length == 3
            mesh.add_polygon( indexes )
          else
            # When triangulate is false, try to make quadfaces. Find out if all the points
            # fit on the same plane.
            if triangulate
              mesh.add_polygon([ indexes[0], indexes[1], indexes[2] ])
              mesh.add_polygon([ indexes[0], indexes[2], indexes[3] ])
            else
              points = pos.collect { |i| pts[i] }
              if TT::Geom3d.planar_points?( points )
                mesh.add_polygon( indexes )
              else
                mesh.add_polygon([ indexes[0], indexes[1], indexes[2] ])
                mesh.add_polygon([ indexes[0], indexes[2], indexes[3] ])
              end
            end # triangulate
          end
        end # x
      end # y
      mesh
    end

    # @return [Nil]
    # @since 1.0.0
    def to_quadmesh( entities, force_triangulation = false )
      fail_if_invalid()
      transformation = Geom::Transformation.new
      pts = mesh_points( parent.subdivs, transformation )
      for y in (0...pts.height-1)
        for x in (0...pts.width-1)
          # Get point for current quad.
          row = y * pts.width
          indexes = [ x+row, x+1+row, x+pts.width+1+row, x+pts.width+row ]
          points = indexes.map { |i| pts[i] }
          # Generate quad.
          if TT::Geom3d.planar_points?( points ) && !force_triangulation
            entities.add_face( points )
          else
            f1 = entities.add_face( points[0], points[1], points[2] )
            f2 = entities.add_face( points[0], points[2], points[3] )
            edge = ( f1.edges & f2.edges ).first
            edge.soft          = true
            edge.smooth        = true
            edge.casts_shadows = false
          end
        end
      end
      nil
    end

    private

    def build_quadmesh(builder, pts)
      for y in (0...pts.height-1)
        for x in (0...pts.width-1)
          # Get point for current quad.
          row = y * pts.width
          indexes = [ x+row, x+1+row, x+pts.width+1+row, x+pts.width+row ]
          points = indexes.map { |i| pts[i] }
          # Generate quad.
          if TT::Geom3d.planar_points?( points ) && !force_triangulation
            builder.add_face( *points )
          else
            f1 = builder.add_face( points[0], points[1], points[2] )
            f2 = builder.add_face( points[0], points[2], points[3] )
            edge = ( f1.edges & f2.edges ).first
            edge.soft          = true
            edge.smooth        = true
            edge.casts_shadows = false
          end
        end
      end
      nil
    end

    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def ordered_edge_control_points
      points = []
      for edgeuse in edgeuses
        if edgeuse.reversed?
          points << edgeuse.edge.control_points.reverse!
        else
          points << edgeuse.edge.control_points
        end
      end
      points
    end

    # Returns an array of segments for the interior grid - exluding the edge
    # segments.
    #
    # @param [Array<Geom::Point3d] points
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def get_control_grid_interior( points )
      fail_if_invalid()
      [
        points.row(1),
        points.row(2),
        points.column(1),
        points.column(2)
      ]
    end

    # @param [BezierVertex] vertex
    # @param [BezierHandle] handle_x
    # @param [BezierHandle] handle_y
    #
    # @return [Geom::Point3d]
    # @since 1.0.0
    def interpolate_points( vertex, handle_x, handle_y )
      line_x = [ handle_x.position, handle_y.vector ]
      line_y = [ handle_y.position, handle_x.vector ]
      intersect = Geom::intersect_line_line( line_x, line_y )
      # (!) intersect.nil? would mean error - or edge case?
      unless intersect
        raise TypeError, "No intersection!\nX:#{line_x.inspect}\nY:#{line_y.inspect}"
      end
      intersect
    end

    # @since 1.0.0
    def interpolate_interior
      # 12 13 14 15
			#  8  9 10 11
			#  4  5  6  7
			#  0  1  2  3
      cpts = control_points

      # INTERIOR POINTS:
      #
      # X---X---X---X
      # |   |   |   |
      # X---2---3---X
      # |   |   |   |
      # X---0---1---X
      # |   |   |   |
      # X---X---X---X
      @interior_points[ 0 ].position = interpolate_points( cpts[ 0], cpts[ 1], cpts[ 4] )
      @interior_points[ 1 ].position = interpolate_points( cpts[ 3], cpts[ 2], cpts[ 7] )
      @interior_points[ 2 ].position = interpolate_points( cpts[12], cpts[13], cpts[ 8] )
      @interior_points[ 3 ].position = interpolate_points( cpts[15], cpts[14], cpts[11] )

      @interior_points.dup
		end

  end # class QuadPatch

end # module
