#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # Central class managing the bezier surface object and data.
  #
  # @since 1.0.0
  class BezierSurface
    
    attr_reader( :patches, :instance )
    attr_accessor( :subdivs )
    
    def initialize( instance )
      @instance = instance
      @patches = []
      @subdivs = 6
    end
    
    # Checks if a given instance (group or component) is a bezier patch.
    #
    # @param [Sketchup::Group|Sketchup::ComponentInstance] instance
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.is?( instance )
      d = TT::Instance.definition( instance )
      return false if d.nil?
      mesh_type = d.get_attribute( ATTR_ID, ATTR_TYPE )
      mesh_type == MESH_TYPE
    end
    
    # Checks if a given instance (group or component) is generated by a
    # compatible version.
    #
    # @param [Sketchup::Group|Sketchup::ComponentInstance] instance
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.version_compatible?( instance )
      d = TT::Instance.definition( instance )
      return false if d.nil?
      string_version = d.get_attribute( ATTR_ID, ATTR_VERSION )
      version = TT::Version.new( string_version )
      MESH_VERSION >= version
    end
    
    # @param [Sketchup::Group|Sketchup::ComponentInstance] instance
    #
    # @private
    # @return [Boolean]
    # @since 1.0.0
    def self.is_old_alpha_format?( instance )
      d = TT::Instance.definition( instance )
      return false if d.nil?
      version = d.get_attribute( ATTR_ID, ATTR_VERSION )
      version == [1,0,0]
    end
    
    # Loads the bezier patch data from the given instance (group or component).
    #
    # @param [Sketchup::Group|Sketchup::ComponentInstance] instance
    #
    # @return [BezierSurface|Nil]
    # @since 1.0.0
    def self.load( instance )
      TT.debug( 'BezierSurface.load' )
      unless self.is?( instance )
        UI.messagebox("This is not a valid bezier surface instance and can not be edited.")
        return nil
      end
      unless self.version_compatible?( instance )
        d = TT::Instance.definition( instance )
        version = d.get_attribute( ATTR_ID, ATTR_VERSION )
        mesh_version = TT::Version.new( version )
        UI.messagebox("This bezier surface was made with a newer version and can not be edited.\n\nMesh Version: #{mesh_version}\nUser Version: #{MESH_VERSION}")
        return nil
      end
      surface = self.new( instance )
      surface.reload
      surface
    end
    
    # Reloads the bezier patch data from the attribute dictionary of the
    # assosiated instance.
    #
    # Use after undo is detected to corrently rebuild the geometry.
    #
    # @return [BezierSurface|Nil]
    # @since 1.0.0
    def reload
      TT.debug( 'BezierSurface.reload' )
      d = TT::Instance.definition( @instance )
      
      # <alpha>
      if self.class.is_old_alpha_format?( instance )
        TT.debug( '> Beta Surface' )
        return self.reload_old_beta
      end
      # </alpha>
      
      self.subdivs = d.get_attribute( ATTR_ID, ATTR_SUBDIVS )
      # Load Patches
      @patches.clear
      attr = d.attribute_dictionaries[ ATTR_ID ]
      attr.each { |key, value|
        # Patch data dictionary:
        # * Key: Patch{index}_{type}
        #        Example: "Patch3_QuadPatch"
        # * Value: Array of [x,y,z] points in inches.
        test = key.match(/Patch(\d+)_(\w+)/)
        next unless test
        # The patch type string is eval'ed into a Class object which is then
        # used to load the patch data. The patch is left with the resonsibility
        # of handling the data loading.
        #
        # (!) Error catching and validation before eval'ing should be added.
        patchtype = eval( test[2] )
        # Load binary data.
        #data = Marshal.load( value ) # (!) Errors about incorrect length.
        data = eval( value )
        reversed = data[P_REVERSED]
        points = data[P_POINTS].map { |pt| Geom::Point3d.new( pt ) }
        # Try to create the patch objects.
        patch = patchtype.new( self, points )
        self.add_patch( patch )
      }
      self
    end
    
    # Reloads the bezier patch data from the attribute dictionary of the
    # assosiated instance.
    #
    # Use after undo is detected to corrently rebuild the geometry.
    #
    # @return [BezierSurface|Nil]
    # @since 1.0.0
    def reload_old_beta
      TT.debug( 'BezierSurface.reload_old_beta' )
      d = TT::Instance.definition( @instance )
      self.subdivs = d.get_attribute( ATTR_ID, ATTR_SUBDIVS )
      # Load Patches
      @patches.clear
      attr = d.attribute_dictionaries[ ATTR_ID ]
      attr.each { |key, value|
        # Patch data dictionary:
        # * Key: Patch{index}_{type}
        #        Example: "Patch3_QuadPatch"
        # * Value: Array of [x,y,z] points in inches.
        test = key.match(/Patch(\d+)_(\w+)/)
        next unless test
        # The patch type string is eval'ed into a Class object which is then
        # used to load the patch data. The patch is left with the resonsibility
        # of handling the data loading.
        #
        # (!) Error catching and validation before eval'ing should be added.
        patchtype = eval( test[2] )
        data = eval( value )
        points = data.map { |pt| Geom::Point3d.new( pt ) }
        self.add_patch( patchtype.new( self, points ) )
      }
      #update_attributes() # (?) Cause SketchUp to crash!
      self
    end
    
    # Updates the mesh and writes the patch data to the attribute dictionary.
    #
    # +transformation+ is usually +model.edit_transform+.
    #
    # @note Remember to wrap in start_operation and commit_operation to ensure
    #       that undo works as expected.
    #
    # @param [Geom::Transformation] transformation
    #
    # @return [Nil]
    # @since 1.0.0
    def update( transformation )
      TT.debug( 'BezierSurface.update' )
      Sketchup.status_text = 'Updating Bezier Surface...'
      update_mesh( @subdivs, transformation )
      update_attributes()
      nil
    end
    
    # Updates the mesh with the given sub-division without writing the data to
    # the attribute dictionary. Use this for live transformation previews.
    #
    # @param [Geom::Transformation] transformation
    # @param [Integer] subdivs
    #
    # @return [Nil]
    # @since 1.0.0
    def preview( transformation, subdivs = 4 )
      #TT.debug( 'Preview Bezier Surface...' )
      Sketchup.status_text = 'Preview Bezier Surface...'
      update_mesh( subdivs, transformation )
      nil
    end
    
    # Adds a +BezierPatch+ to the +BezierSurface+.
    #
    # @param [BezierPatch] patch
    #
    # @return [BezierPatch]
    # @since 1.0.0
    def add_patch( patch )
      raise ArgumentError, 'Not a BezierPatch.' unless patch.is_a?(BezierPatch)
      @patches << patch
      patch
    end
    
    # Estimates the number of vertices in the BezierSurface.
    #
    # (!) Is not accurate - does not take into account patches that share points.
    #
    # @param [Integer] subdivs
    #
    # @return [Integer]
    # @since 1.0.0
    def count_mesh_points( subdivs )
      count = 0
      for patch in @patches
        count += patch.count_mesh_points( subdivs )
      end
      count
    end
    
    # Estimates the number of polygons (triangles) in the BezierSurface.
    #
    # (!) Is not accurate - does not take into account patches that share polygon
    # edges. Also - if the mesh is not always triangulated there might be less
    # polygons.
    #
    # @param [Integer] subdivs
    #
    # @return [Integer]
    # @since 1.0.0
    def count_mesh_polygons( subdivs )
      count = 0
      for patch in @patches
        count += patch.count_mesh_polygons( subdivs )
      end
      count
    end
    
    # Returns the control points for all the paches in the surface.
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points
      pts = []
      for patch in @patches
        pts.concat( patch.control_points.to_a )
      end
      pts.uniq!
      pts
    end
    
    # Returns the picked control points for the given x, y screen co-ordinates.
    #
    # (!) Currently returns an array - might be multiple points returned if they
    # occupy similar screen co-ordinates. This should perhaps return only one
    # point.
    #
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def pick_control_points(x, y, view)
      picked = []
      for patch in @patches
        points = patch.pick_control_points( x, y, view )
        picked.concat( points ) unless points.nil?
      end
      #( picked.empty? ) ? nil : picked.uniq
      picked.uniq
    end
    
    # @param [Integer] subdivs
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @return [Array<BezierEdge>]
    # @since 1.0.0
    def pick_edges(subdivs, x, y, view)
      picked = []
      for patch in @patches
        edges = patch.pick_edges( subdivs, x, y, view )
        picked.concat( edges ) unless edges.nil?
      end
      #( picked.empty? ) ? nil : picked.uniq
      picked.uniq
    end
    
    # Draws the control grid structure for all the paches in the surface.
    #
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_control_grid(view)
      for patch in @patches
        patch.draw_control_grid( view )
      end
      nil
    end
    
    # Draws the internal subdivided structure for all the paches in the surface.
    #
    # @param [Sketchup::View] view
    # @param [Boolean] preview
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_grid(view, preview = false)
      for patch in @patches
        if preview
          patch.draw_grid( preview, view )
        else
          patch.draw_grid( @subdivs, view )
        end
      end
      nil
    end
    
    # <debug>
    def draw_edges( view )
      tr = view.model.edit_transform
      subdivs = @subdivs
      for patch in @patches
        for edge in patch.edges
          pts = edge.segment( subdivs, tr )
          
          if edge.reversed_in?( patch )
            view.drawing_color = 'purple'
            d = pts[-1].vector_to( pts[-2] )
            pt = pts[-2]
          else
            view.drawing_color = 'green'
            d = pts[0].vector_to( pts[1] )
            pt = pts[1]
          end
          
          v = d * Z_AXIS
          view.line_width = 4
          view.line_stipple = ''
          
          size = view.pixels_to_model( 25, pt )
          o = pt.offset( v, size )
          
          view.draw_line( pt, o )
        end
      end
    end
    # </debug>
    
    # Returns all the +BezierEdge+ entities for the surface.
    #
    # @return [Array<BezierEdge>]
    # @since 1.0.0
    def edges
      edges = []
      for patch in @patches
        edges.concat( patch.edges )
      end
      edges.uniq!
      edges
    end
    
    def outer_loop
      # ...
    end
    
    # Returns all the 3d points for the surface mesh.
    #
    # @param [Integer] subdivs
    # @param [Geom::Transformation] tranformation
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def mesh_points( subdivs, transformation )
      points = []
      for patch in @patches
        points.concat( patch.mesh_points( subdivs, transformation ).to_a )
      end
      points = TT::Point3d.extend_all( points ) # So that .uniq! works
      points.uniq!
      points
    end
    
    # Returns all the vertices for the surface mesh in the same order as
    # #mesh_points.
    #
    # @param [Integer] subdivs
    # @param [Geom::Transformation] tranformation
    #
    # @return [Array<Sketchup::Vertex>]
    # @since 1.0.0
    def mesh_vertices( subdivs, transformation )
      d = TT::Instance.definition( @instance )
      pts = mesh_points( subdivs, transformation )
      vertices = raw_mesh_vertices()
      
      unless pts.length == vertices.length
        TT.debug( 'mesh_vertices' )
        TT.debug( "> Points: #{pts.length}" )
        TT.debug( "> Vertices: #{vertices.length}" )
      end
      
      patch_vertices = []
      for pt in pts
        vertex = vertices.find { |v| v.position == pt } # (!) Optimize
        patch_vertices << vertex
        vertices.delete( vertex )
      end
      patch_vertices
    end
    
    # Moves the given set of vertices to new positions.
    #
    # @param [Array<Sketchup::Vertex>] vertices
    # @param [Array<Geom::Point3d>] positions
    #
    # @return [Boolean]
    # @since 1.0.0
    def set_vertex_positions( vertices, positions )
      #TT::debug 'set_vertex_positions'
      #TT::debug '> vertices'
      #TT::debug vertices
      #TT::debug '> position'
      #TT::debug positions
      entities = []
      vectors = []
      vertices.each_with_index { |v,i|
        #TT::debug v.position
        #TT::debug positions[i]
        vector = v.position.vector_to( positions[i] )
        #vectors << vector if vector.valid?
        if vector.valid?
          entities << v
          vectors << vector
        end
      }
      #TT::debug vectors
      #TT::debug "Vertices: #{entities.length} - Vectors: #{vectors.length}"
      # (!) ensure entities has same length as vectors
      d = TT::Instance.definition( @instance )
      d.entities.transform_by_vectors( entities, vectors )
      true
    end
    
    private
    
    # Returns all vertices for the surface unordered.
    #
    # @return [Array<Sketchup::Vertex>]
    # @since 1.0.0
    def raw_mesh_vertices
      vs = []
      d = TT::Instance.definition( @instance )
      d.entities.each { |e|
        next unless e.is_a?( Sketchup::Edge )
        vs.concat( e.vertices )
      }
      vs.uniq!
      vs
    end
    
    # Updates the attribute dictionary with the BezierSurface data.
    #
    # @return [Boolean]
    # @since 1.0.0
    def update_attributes
      d = TT::Instance.definition( @instance )
      # Write Surface data
      d.set_attribute( ATTR_ID, ATTR_TYPE, MESH_TYPE )
      d.set_attribute( ATTR_ID, ATTR_VERSION, MESH_VERSION.to_s )
      d.set_attribute( ATTR_ID, ATTR_SUBDIVS, @subdivs )
      # Write Patches
      @patches.each_with_index { |patch, i|
        section = "Patch#{i}_#{patch.typename}"
        # Convert the control points into arrays of floats because the custom
        # objects doesn't support Marshal.
        points = patch.control_points.to_a.map { |pt|
          [ pt.x.to_f, pt.y.to_f, pt.z.to_f ]
        }
        # Build hash with binary patch data and write to dictionary.
        data = {}
        data[P_REVERSED] = patch.reversed
        data[P_POINTS] = points
        #binary = Marshal.dump( data )
        binary = data.inspect
        d.set_attribute( ATTR_ID, section, binary )
      }
      true
    end
    
    # Regenerates the mesh from the BezierSurface data.
    #
    # @param [Integer] subdivs
    # @param [Geom::Transformation] tranformation
    #
    # @return [Boolean]
    # @since 1.0.0
    def update_mesh( subdivs, transformation )
      d = TT::Instance.definition( @instance )
      points = count_mesh_points( subdivs )
      polygons = count_mesh_polygons( subdivs )
      mesh = Geom::PolygonMesh.new( points, polygons )
      @patches.each { |patch|
        patch.add_to_mesh( mesh, subdivs, transformation )
      }
      d.entities.clear!
      d.entities.fill_from_mesh( mesh, true, TT::MESH_SOFT_SMOOTH )
    end
    
  end # class BezierSurface

end # module