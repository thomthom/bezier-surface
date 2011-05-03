#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require File.join( TT::Plugins::BezierSurfaceTools::PATH, 'bezier_patch.rb' )


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
      TT.debug 'QuadPatch.new'
      
      # Validate arguments
      raise ArgumentError, 'points not an Array.' unless points.is_a?(Array)
      raise ArgumentError, 'points must have 16 Point3d' unless points.size == 16
      unless points.all? { |point|
        point.is_a?( Geom::Point3d )
      }
        raise ArgumentError, 'points must be Point3d objects.'
      end
      #TT::Point3d.extend_all( points )
      
      # Init superclass. (Extends points into Point3d_Ex.)
      super
      
      # Create edges and assosiate them with this patch.
      grid = TT::Dimension.new( points, 4, 4 )
      
      # Order of edges and direction of their control points.
      #
      #  Y - Columns
      #
      #  ^
      #  |
      #
      #  x --> X - Rows
      #
      # +---<---+
      # |   2   |
      # v3     1^
      # |   0   |
      # +--->---+
      #   
      # Edge 2 and 3 is initially reversed.
      edge = BezierEdge.new( parent, grid.row(0) )
      edge.link( self )
      edgeuse = BezierEdgeUse.new( self, edge, false )
      @edgeuses << edgeuse
      
      edge = BezierEdge.new( parent, grid.column(3) )
      edge.link( self )
      edgeuse = BezierEdgeUse.new( self, edge, false )
      @edgeuses << edgeuse
      
      edge = BezierEdge.new( parent, grid.row(3).reverse )
      edge.link( self )
      edgeuse = BezierEdgeUse.new( self, edge, false )
      @edgeuses << edgeuse
      
      edge = BezierEdge.new( parent, grid.column(0).reverse )
      edge.link( self )
      edgeuse = BezierEdgeUse.new( self, edge, false )
      @edgeuses << edgeuse
      
      # (!) Hack - clean up!
      merge_vertices()
      
      # Interior patch points - indirectly controlled by the edges.
      @interior_points = TT::Dimension.new( [
        BezierInteriorPoint.new( parent, points[5] ),
        BezierInteriorPoint.new( parent, points[6] ),
        BezierInteriorPoint.new( parent, points[9] ),
        BezierInteriorPoint.new( parent, points[10] )
      ], 2, 2 )
      
      for point in control_points
        point.link( self )
      end
    end
    
    # @private (protected)
    #
    # @return [Nil]
    # @since 1.0.0
    def merge_vertices
      # (!) Hack - clean up!
      e0, e1, e2, e3 = edges
      e1.start = e0.end
      e1.end = e2.start
      e3.start = e2.end
      e3.end = e0.start
      nil
    end
    
    # @return [QuadPatch]
    # @since 1.0.0
    def self.restore( surface, edgeuses, interior_points, reversed )
      TT.debug 'QuadPatch.restore'
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
      patch.reversed = reversed
      patch.edgeuses.each_with_index { |edgeuse, index|
        prototype = edgeuses[ index ]
        edgeuse.edge = prototype.edge
        edgeuse.edge.link( patch )
        edgeuse.reversed = prototype.reversed?
      }
      patch.merge_vertices
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
      # X---X---X---X
      # |   |   |   |
      # X---X---X---X
      # |   |   |   |
      # X---X---X---X
      # |   |   |   |
      # X---X---X---X
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
    
    # @private
    #
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
    
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def positions
      fail_if_invalid()
      control_points.map { |control_point|
        control_point.position
      }
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
    
    # Returns a set of 3d points for this patch using the given sub-division.
    # 
    # @param [Integer] subdivs
    # @param [Geom::Transformation] transformation
    #
    # @return [TT::Dimension]
    # @since 1.0.0
    def mesh_points( subdiv, transformation )
      fail_if_invalid()
      # Transform to active model space
      cpoints = positions()
      wpts = cpoints.map { |pt| pt.transform( transformation ) }
      # Calculate Bezier mesh points.
      pass1 = TT::Dimension.new( subdiv+1, 4 )
      wpts.each_row { |row, index|
        pass1.set_row( index, TT::Geom3d::Bezier.points(row, subdiv) )
      }
      points = TT::Dimension.new( subdiv+1, subdiv+1 )
      pass1.each_column { |column, index|
        points.set_column( index, TT::Geom3d::Bezier.points(column, subdiv) )
      }
      points
    end
    
    # Returns an array of +BezierEdge+ objects in clock-wise order.
    #
    # @return [Array<BezierEdge>]
    # @since 1.0.0
    def edges
      fail_if_invalid()
      @edgeuses.map { |edgeuse| edgeuse.edge }
    end
    
    # (?) Private
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
        #pts.each_row { |row|
          view.draw( GL_LINE_STRIP, row )
        }
        pts.columns[1...pts.height-1].each { |col|
        #pts.each_column { |col|
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
      #inversed = false # (?) Instance variable
      inversed = self.reversed # (!)

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
    
  end # class QuadPatch

end # module