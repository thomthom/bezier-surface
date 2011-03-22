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
    def initialize( points )
      super
      raise ArgumentError, 'points not an Array.' unless points.is_a?(Array)
      raise ArgumentError, 'points must have 16 Point3d' unless points.size == 16
      unless points.all? { |point|
        point.is_a?( Geom::Point3d )
      }
        raise ArgumentError, 'points must be Point3d objects.'
      end
      @points = TT::Dimension.new( points, 4, 4 )
      
      # Create edges and assosiate them with this patch.
      @edges = [
        BezierEdge.new( @points.row(0) ),
        BezierEdge.new( @points.column(3) ),
        BezierEdge.new( @points.row(3) ),
        BezierEdge.new( @points.column(0) )
      ].each { |edge|
        edge.link( self )
      }
    end
    
    # Used when writing the bezier data to attribute dictionaries.
    #
    # @return [String]
    # @since 1.0.0
    def typename
      'QuadPatch'
    end
    
    # @param [BezierSurface] surface
    # @param [BezierEdge] edge
    #
    # @return [QuadPatch]
    # @since 1.0.0
    def self.extrude_edge( surface, edge )
      if edge.patches.size > 1
        raise ArgumentError, 'Can not extrude edge connected to more than one patch.'
      end
      
      patch = edge.patches[0]
      reversed = edge.reversed_in?( patch )
      
      prev_edge = patch.prev_edge( edge )
      next_edge = patch.next_edge( edge )
      
      TT.debug( "> Prev Edge: #{prev_edge}" )
      TT.debug( "> Next Edge: #{next_edge}" )
      
      pts1 = prev_edge.control_points
      pts2 = next_edge.control_points
      
      if prev_edge.start == edge.start
        v1 = pts1[0].vector_to( pts1[1] ).reverse
      else
        v1 = pts1[3].vector_to( pts1[2] ).reverse
      end
      
      if next_edge.start == edge.end
        v2 = pts2[0].vector_to( pts2[1] ).reverse
      else
        v2 = pts2[3].vector_to( pts2[2] ).reverse
      end
      
      #if reversed
      #  v1.reverse!
      #  v2.reverse!
      #end
      
      directions = [ v1, v1, v2, v2 ]

      length = edge.length( surface.subdivs ) / 3
      
      points = []
      edge.control_points.each_with_index { |point, index|
        points << point.clone
        points << point.offset( directions[index], length )
        points << point.offset( directions[index], length * 2 )
        points << point.offset( directions[index], length * 3 )
      }
      
      new_patch = QuadPatch.new( points )
      new_patch.reversed = true if reversed
      edge.link( new_patch )
      # (!) merge edges
      
      model = Sketchup.active_model
      model.start_operation('Add Quad Patch', true)
      surface.add_patch( new_patch )
      surface.update( model.edit_transform )
      model.commit_operation
      
      new_patch
    end
    
    # (!) private
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
    
    # (!) private
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
    
    # (!) private
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
    
    # @param [BezierEdge] edge
    #
    # @return [Boolean]
    # @since 1.0.0
    def edge_reversed?( edge )
      # (!) Not correct!
      TT.debug( 'QuadPatch.edge_reversed?' )
      index = edge_index( edge )
      if index == 2 || index == 3
        TT.debug( "> Reversed" )
        return true
      else
        TT.debug( "> Normal" )
        return false
      end
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
      # (i) BezierEdge objects doesn't maintain an updated reference to the
      # control points when they are manipulated. (?) Update the points
      # before returning the edges.
      #
      # (i) Don't hold on to BezierEdge objects for their 3d data.
      @edges[0].control_points = @points.row(0)
      @edges[1].control_points = @points.column(3)
      @edges[2].control_points = @points.row(3)
      @edges[3].control_points = @points.column(0)
      @edges
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