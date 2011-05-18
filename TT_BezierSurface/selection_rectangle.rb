#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  class SelectionRectangle
    
    attr_accessor( :start, :end )
    
    # @since 1.0.0
    def initialize
      @start = nil  # Geom::Point3d
      @end = nil    # Geom::Point3d
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
    def selected?( view, point_or_segment )
      return false unless valid?
      is_selected?( view, point_or_segment, selection_polygon() )
    end
    
    # @param [Sketchup::View] view
    # @param [Mixed] points_or_segments
    #
    # @return [Mixed]
    # @since 1.0.0
    def selected_items( view, points_or_segments )
      return false unless valid?
      polygon = selection_polygon()
      points_or_segments.select { |item|
        is_selected?( view, point_or_segment, polygon )
      }
    end
    
    private
    
    # @param [Sketchup::View] view
    # @param [Mixed] point_or_segment
    #
    # @return [Boolean]
    # @since 1.0.0
    def is_selected?( view, point_or_segment, polygon )
      if point_or_segment.is_a?( Geom::Point3d )
        in_polygon?( view, [item], polygon )
      elsif point_or_segment.is_a?( Array )
        in_polygon?( view, item, polygon )
      else
        raise ArgumentError, 'Argument must be Point3d or a segment.'
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