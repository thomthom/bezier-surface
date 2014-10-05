#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  class SelectionRectangle

    SUBDIVS = 6

    attr_accessor( :start, :end )

    # @since 1.0.0
    def initialize( surface )
      @surface = surface
      @start = nil  # Geom::Point3d
      @end = nil    # Geom::Point3d
    end

    # @since 1.0.0
    def reset
      @start = nil
      @end = nil
    end

    # @return [Boolean]
    # @since 1.0.0
    def valid?
      @start && @end
    end

    # @return [Boolean]
    # @since 1.0.0
    def left_to_right?
      return false unless valid?
      @start.x < @end.x
    end

    # @param [Sketchup::View] view
    #
    # @return [Boolean]
    # @since 1.0.0
    def draw( view )
      return false unless valid?
      view.line_stipple = (left_to_right?) ? '' : '_'
      view.line_width = 2
      view.drawing_color = CLR_SELECTION
      view.draw2d( GL_LINE_LOOP, selection_polygon() )
      true
    end

    # @param [Sketchup::View] view
    # @param [Mixed] point_or_segment
    #
    # @return [Boolean]
    # @since 1.0.0
    def selected?( view, entity )
      return false unless valid?
      polygon = selection_polygon()
      transformation = view.model.edit_transform
      is_selected?( view, entity, transformation, polygon )
    end

    # @param [Sketchup::View] view
    # @param [Mixed] points_or_segments
    #
    # @return [Mixed]
    # @since 1.0.0
    def selected_entities( view, entities )
      return [] unless valid?
      polygon = selection_polygon()
      transformation = view.model.edit_transform
      entities.select { |entity|
        is_selected?( view, entity, transformation, polygon )
      }
    end

    private

    # @param [Sketchup::View] view
    # @param [Mixed] point_or_segment
    #
    # @return [Boolean]
    # @since 1.0.0
    def is_selected?( view, entity, transformation, polygon )
      if entity.is_a?( BezierControlPoint )
        point = entity.position.transform( transformation )
        in_polygon?( view, [point], polygon )
      elsif entity.is_a?( BezierEdge )
        segment = entity.segment( SUBDIVS, transformation )
        in_polygon?( view, segment, polygon )
      elsif entity.is_a?( BezierPatch )
        points = entity.mesh_points( SUBDIVS, transformation )
        in_polygon?( view, points, polygon )
      else
        raise ArgumentError, 'Argument must be BezierControlPoint or a BezierEdge.'
      end
    end

    # @param [Sketchup::View] view
    # @param [Array<Geom::Point3d>] points
    # @param [Array<Geom::Point3d>] polygon
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def in_polygon?( view, points, polygon )
      if left_to_right?
        points.all? { |point|
          screen_point = view.screen_coords( point )
          Geom.point_in_polygon_2D( screen_point, polygon, true )
        }
      else
        # (!) Check intersection.
        points.any? { |point|
          screen_point = view.screen_coords( point )
          Geom.point_in_polygon_2D( screen_point, polygon, true )
        }
      end
    end

    # Generate selection polygon
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def selection_polygon
      pt1 = @start
      pt3 = @end
      pt2 = @start.clone
      pt2.x = pt3.x
      pt4 = @start.clone
      pt4.y = pt3.y
      [ pt1, pt2, pt3, pt4 ]
    end

  end # class SelectionRectangle

end # module
