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
  class QuadPatch
    include BezierPatch
    
    #attr_reader( :points )
    
    # @param [Array<Geom::Point3d>] points Bezier control points
    #
    # @since 1.0.0
    def initialize( parent, points )
      super
      raise ArgumentError, 'points not an Array.' unless points.is_a?(Array)
      raise ArgumentError, 'points must have 16 Point3d' unless points.size == 16
      unless points.all? { |point|
        point.is_a?( Geom::Point3d )
      }
        raise ArgumentError, 'points must be Point3d objects.'
      end
      
      TT::Point3d.extend_all( points ) # TT::Point3d_Ex
      
      # Create edges and assosiate them with this patch.
      grid = TT::Dimension.new( points, 4, 4 )
      @edges = [
        BezierEdge.new( parent, grid.row(0) ),
        BezierEdge.new( parent, grid.column(3) ),
        BezierEdge.new( parent, grid.row(3) ),
        BezierEdge.new( parent, grid.column(0) )
      ].each { |edge|
        edge.link( self )
      }
      
      # Interior patch points - indirectly controlled by the edges.
      @interior_points = TT::Dimension.new( [
        points[5],
        points[6],
        points[9],
        points[10]
      ], 2, 2 )
    end
    
    # Used when writing the bezier data to attribute dictionaries.
    #
    # @return [String]
    # @since 1.0.0
    def typename
      'QuadPatch'
    end
    
    # Returns the control points for this BezierPatch.
    #
    # @example:
    #  0---1---2---3
    #  |   |   |   |
    #  4---5---6---7
    #  |   |   |   |
    #  8---9---10--11
    #  |   |   |   |
    #  12--13--14--15
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points
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
      # 0---1---2---3
      # |   |   |   |
      # 4---5---6---7
      # |   |   |   |
      # 8---9---10--11
      # |   |   |   |
      # 12--13--14--15
      #
      # EDGES:
      #
      # X-----0-----X
      # |   |   |   |
      # |---X---X---|
      # 3   |   |   1
      # |---X---X---|
      # |   |   |   |
      # X-----2-----X
      #
      # INTERIOR POINTS:
      #
      # X---X---X---X
      # |   |   |   |
      # X---0---1---X
      # |   |   |   |
      # X---2---3---X
      # |   |   |   |
      # X---X---X---X
      #
      edges = edges()
      # Row 1
      points = edges[0].control_points
      # Row 2
      points << edges[3].control_points[1]
      points << @interior_points[0]
      points << @interior_points[1]
      points << edges[1].control_points[1]
      # Row 3
      points << edges[3].control_points[2]
      points << @interior_points[2]
      points << @interior_points[3]
      points << edges[1].control_points[2]
      # Row 4
      points.concat( edges[2].control_points )
      # Matrix
      matrix = TT::Dimension.new( points, 4, 4 )
      matrix
    end
    
    # @param [BezierEdge] edge
    #
    # @return [Boolean]
    # @since 1.0.0
    def edge_reversed?( edge )
      # (!) Not correct!
      #TT.debug( 'QuadPatch.edge_reversed?' )
      index = edge_index( edge )
      if index == 2 || index == 3
        #TT.debug( "> Reversed" )
        is_reversed = true
      else
        #TT.debug( "> Normal" )
        is_reversed = false
      end
      is_reversed = !is_reversed if @reversed
      is_reversed
    end
    
    # Accurate calculation of the number of vertices in the mesh.
    #
    # @param [Integer] subdivs
    #
    # @return [Integer]
    # @since 1.0.0
    def count_mesh_points( subdiv )
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
      # Transform to active model space
      cpoints = control_points()
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
      @edges.dup
    end
    
    # (?) Private
    #
    # @param [Array<Geom::Point3d] points
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def get_control_grid_border( points )
      [
        points.row(0),
        points.column(3),
        points.row(3),
        points.column(0)
      ]
    end
    
    # (?) Private
    #
    # @param [Array<Geom::Point3d] points
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def get_control_grid_interior( points )
      [
        points.row(1),
        points.row(2),
        points.column(1),
        points.column(2)
      ]
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
      triangulate = false # (?) Instance variable
      #inversed = false # (?) Instance variable
      inversed = self.reversed

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