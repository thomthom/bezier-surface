#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  # @since 1.0.0
  class BezierControlPoint < BezierEntity
    
    attr_reader( :position )
    
    def initialize( parent, *args )
      super()
      @parent = parent
      @links[ BezierEdge ] = []
      @links[ BezierPatch ] = []
      set( *args )
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def is_interior?
      fail_if_invalid()
      # Subclass BezierInteriorPoint returns true
      false
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def is_handle?
      fail_if_invalid()
      # Subclass BezierHandle returns true
      false
    end
    
    # @return [Array<BezierEdge>]
    # @since 1.0.0
    def edges
      fail_if_invalid()
      @links[ BezierEdge ].dup
    end
    
    # @return [Array<BezierPatch>]
    # @since 1.0.0
    def patches
      fail_if_invalid()
      @links[ BezierPatch ].dup
    end
    
    # Sets a new position for the controlpoint.
    #
    # (?) alias position= ?
    #
    # @return [Geom::Point3d]
    # @since 1.0.0
    def set( *args )
      fail_if_invalid()
      if args.size == 1
        # .set( Geom::Point3d )
        # .set( [ x, y, z ] )
        arg = args[0]
        if arg.is_a?( Geom::Point3d )
          @position = arg
        elsif arg.is_a?( Array )
          if arg.all? { |i| i.is_a?( Numeric ) }
            @position = Geom.Point3d.new( *arg )
          else
            raise ArgumentError, 'Array does not contain all Numeric.'
          end
        end
      elsif args.size == 3
        # .set( x, y, z )
        if args.all? { |i| i.is_a?( Numeric ) }
          @position = Geom.Point3d.new( *args )
        else
          raise ArgumentError, 'Arguments not all Numeric.'
        end
      else
        raise ArgumentError, "Invalid arguments. (#{args.size})"
      end
      @position.extend( TT::Point3d_Ex ) # Needed?
      @position
    end
    
    # @return [Geom::Point3d]
    # @since 1.0.0
    def position=( new_pt )
      fail_if_invalid()
      set( new_pt )
    end
    
  end # class BezierVertex
  
  
  # BezierPatch & BezierEdge vertex.
  #
  # @since 1.0.0
  class BezierVertex < BezierControlPoint
    
    # @since 1.0.0
    def initialize( *args )
      super
      @links[ BezierHandle ] = []
      @links[ BezierInteriorPoint ] = []
    end
    
    # @return [Array<BezierHandle>]
    # @since 1.0.0
    def handles
      fail_if_invalid()
      @links[ BezierHandle ].dup
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def linked_control_points
      fail_if_invalid()
      cpoints = @links[ BezierHandle ].dup
      for patch in patches
        next unless patch.automatic?
        for cpoint in patch.interior_points
          cpoints << cpoint if self.used_by?( cpoint )
        end
      end
      cpoints
    end

    # @return [Boolean]
    # @since 1.0.0
    def move!( arg )
      fail_if_invalid()
      if arg.is_a?( Geom::Vector3d )
        vector = arg
      elsif arg.is_a?( Geom::Point3d )
        vector = position.vector_to( arg )
      else
        raise ArgumentError, "Argument must be a point or vector. (#{arg.class.name})"
      end
      for control_point in linked_control_points
        control_point.position = control_point.position.offset( vector )
      end
    end
  
  end # class BezierInteriorPoint
  
  
  # BezierEdge control handle points.
  #
  # @since 1.0.0
  class BezierHandle < BezierControlPoint
    
    # @since 1.0.0
    def initialize( *args )
      super
      @links[ BezierVertex ] = []
      @linked = true
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def is_handle?
      fail_if_invalid()
      true
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def linked?
      fail_if_invalid()
      @linked == true
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def linked=( is_linked )
      fail_if_invalid()
      @linked = ( is_linked == true )
    end
    
    # @return [Array<BezierHandle>]
    # @since 1.0.0
    def linked_handles
      fail_if_invalid()
      handles = @links[ BezierVertex ].map { |vertex|
        vertex.handles.select { |handle| handle.linked? }
      }
      handles.flatten!
      handles.uniq!
      handles.delete( self )
      handles
    end

    # @return [BezierVertex]
    # @since 1.0.0
    def length=( new_length )
      fail_if_invalid()
      new_point = vertex.position.offset( vector, new_length )
      set( new_point )
    end
    
    # @return [BezierVertex]
    # @since 1.0.0
    def vertex
      fail_if_invalid()
      @links[ BezierVertex ].first
    end
    
    # @return [Geom::Vector3d]
    # @since 1.0.0
    def vector
      fail_if_invalid()
      vertex.position.vector_to( @position )
    end

    # @return [Geom::Vector3d]
    # @since 1.0.0
    def vector=( new_vector )
      fail_if_invalid()
      position = vertex.position.offset( new_vector )
    end
  
  end # class BezierHandle
  
  
  # BezierPatch interior control points.
  #
  # @since 1.0.0
  class BezierInteriorPoint < BezierControlPoint
    
    # @since 1.0.0
    def initialize( *args )
      super
      @links[ BezierVertex ] = []
      @links[ BezierHandle ] = []
    end
    
    # @return [Boolean]
    # @since 1.0.0
    def is_interior?
      fail_if_invalid()
      true
    end
  
  end # class BezierInteriorPoint

end # module