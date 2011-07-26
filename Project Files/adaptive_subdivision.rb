# load 'tests/tt_bezier.rb'

module TT::Test
  
  # sel[0].curve.get_attribute( "skp", "crvpts" )
  def self.calculate_segments( points, max_angle )
    segments = 2
    until self.max_angle( TT::Geom3d::Bezier.points( points, segments ) ) <= max_angle
      segments += 1
    end
    segments
  end
  
  def self.max_angle( points )
    max = nil
    for i in 0...points.size-2
      v1 = points[i].vector_to( points[i+1] )
      v2 = points[i+1].vector_to( points[i+2] )
      angle = v1.angle_between( v2 )
      if max.nil? || angle > max
        max = angle
      end
    end
    max
  end
  
  # s=TT::Test.calculate_segments( pts, 70.degrees ); model.active_entities.add_curve( TT::Geom3d::Bezier.points(pts,s) );nil
  def self.test_bezier( points, max_angle = 30.degrees )
    segments = self.calculate_segments( points, max_angle )
    puts "Segments: #{segments}"
  end

end