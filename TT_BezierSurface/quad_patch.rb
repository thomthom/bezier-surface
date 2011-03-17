#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

#require 'TT_BezierPatch/bezier_patch.rb'
require File.join( TT::Plugins::BezierSurfaceTools::PATH, 'bezier_patch.rb' )


module TT::Plugins::BezierSurfaceTools
  
  class QuadPatch
    include BezierPatch
    
    #attr_reader( :points )
    
    def initialize( points )
      super
      raise ArgumentError, 'points not an Array.' unless points.is_a?(Array)
      raise ArgumentError, 'points must have 16 Point3d' unless points.size == 16
      @points = TT::Dimension.new( points, 4, 4 )
    end
    
    def typename
      'QuadPatch'
    end
    
    # Accurate calculation of the number of vertices in the mesh.
    def count_mesh_points( subdiv )
      ( subdiv + 1 ) * ( subdiv + 1 )
    end
    
    # Maximum number of polygons in a patch. If the patch tries to maintain
    # quad-faces when possible the actual number of polygons might be less.
    def count_mesh_polygons( subdiv )
      subdiv * subdiv * 2
    end
    
    # @return [TT::Dimension]
    def mesh_points( subdiv, transformation )
      # Transform to active model space
      wpts = @points.map { |pt| pt.transform( transformation ) }
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
      # (!) Edges can't be created dynamically like this. They need to be
      # created when the QuadPatch is initialized and then updated when
      # requested. BezierEdge objects need to maintain references to the
      # patches it's connected to.
      [
        BezierEdge.new( @points.row(0) ),
        BezierEdge.new( @points.column(3) ),
        BezierEdge.new( @points.row(3) ),
        BezierEdge.new( @points.column(0) )
      ]
    end
    
    # (?) Private
    def get_control_grid_border( points )
      [
        points.row(0),
        points.column(3),
        points.row(3),
        points.column(0)
      ]
    end
    
    # (?) Private
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
    # @param [Geom::PolygonMesh] pm
    #
    # @return [nil]
    def add_to_mesh( pm, subdiv, transformation )
      triangulate = false # (?) Instance variable
      mirror = false # (?) Instance variable

      p = mesh_points( subdiv, transformation )
      
      # Add points to point list and build index.
      pi = []
      p.each { |i|
        pi << pm.add_point(i)
      }
      
      0.upto(p.height-2) { |y|
        0.upto(p.width-2) { |x|
          r = y * p.width # Current row
          # Pick out the indexes from the patch 2D-matrix we're interested in.
          pos = [ x+r, x+1+r, x+p.width+1+r, x+p.width+r ]
          # Get the point indexes and mirror orientation
          indexes = pos.collect { |i| pi[i] }
          indexes.reverse! if mirror

          next unless indexes.length > 2
          
          if indexes.length == 3
            pm.add_polygon(indexes)
          else
            # When triangulate is false, try to make quadfaces. Find out if all the points
            # fit on the same plane.
            if triangulate 
              pm.add_polygon([ indexes[0], indexes[1], indexes[2] ])
              pm.add_polygon([ indexes[0], indexes[2], indexes[3] ])
            else
              points = pos.collect { |i| p[i] }
              if TT::Geom3d.planar_points?(points)
                pm.add_polygon(indexes)
              else
                pm.add_polygon([ indexes[0], indexes[1], indexes[2] ])
                pm.add_polygon([ indexes[0], indexes[2], indexes[3] ])
              end
            end
          end
        }
      }
      return pm
    end
    
  end # class QuadPatch

end # module