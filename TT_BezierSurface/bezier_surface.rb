#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


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
      mesh_type = d.get_attribute( ATTR_ID, 'Type' )
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
      version = d.get_attribute( ATTR_ID, 'Version' )
      return false unless version
      return false if MESH_VERSION[0] < version[0]
      return false if MESH_VERSION[0] == version[0] && MESH_VERSION[1] < version[1]
      return false if MESH_VERSION[1] == version[1] && MESH_VERSION[2] < version[2]
      true
    end
    
    # Loads the bezier patch data from the given instance (group or component).
    #
    # @param [Sketchup::Group|Sketchup::ComponentInstance] instance
    #
    # @return [BezierSurface|Nil]
    # @since 1.0.0
    def self.load( instance )
      TT.debug( 'BezierSurface.load' )
      return nil unless self.is?( instance )
      # (!) Validate version
      # self.version_compatible?( instance )
      surface = self.new( instance )
      surface.reload
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
      self.subdivs = d.get_attribute( ATTR_ID, 'Subdivs' )
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
        self.add_patch( patchtype.new( points ) )
      }
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
      TT.debug( 'Updating Bezier Surface...' )
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
      @patches.each { |patch|
        count += patch.count_mesh_points( subdivs )
      }
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
      @patches.each { |patch|
        count += patch.count_mesh_polygons( subdivs )
      }
      count
    end
    
    # Returns the control points for all the paches in the surface.
    #
    # @return [Array<Geom::Point3d>]
    # @since 1.0.0
    def control_points
      pts = []
      @patches.each { |patch|
        pts.concat( patch.control_points.to_a )
      }
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
      @patches.each { |patch|
        points = patch.pick_control_points( x, y, view )
        picked.concat( points ) unless points.nil?
      }
      #( picked.empty? ) ? nil : picked.uniq
      picked.uniq
    end
    
    # (!) Placeholder method. BezierEdges not implemented.
    #
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @return [Array<BezierEdge>]
    # @since 1.0.0
    def pick_edges(subdivs, x, y, view)
      picked = []
      @patches.each { |patch|
        points = patch.pick_edges( subdivs, x, y, views )
        picked.concat( points ) unless points.nil?
      }
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
      @patches.each { |patch|
        patch.draw_control_grid( view )
      }
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
      @patches.each { |patch|
        if preview
          patch.draw_grid( preview, view )
        else
          patch.draw_grid( @subdivs, view )
        end
      }
      nil
    end
    
    # Returns all the +BezierEdge+ entities for the surface.
    #
    # @return [Array<BezierEdge>]
    # @since 1.0.0
    def edges
      edges = []
      @patches.each { |patch|
        edges.concat( patch.edges )
      }
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
      pts = []
      @patches.each { |patch|
        pts.concat( patch.mesh_points( subdivs, transformation ).to_a )
      }
      pts.uniq! # (!) custom uniq to only return uniqe 3d positions.
      pts
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
      d.set_attribute( ATTR_ID, 'Type', MESH_TYPE )
      d.set_attribute( ATTR_ID, 'Version', MESH_VERSION )
      d.set_attribute( ATTR_ID, 'Subdivs', @subdivs )
      # Write Patches
      @patches.each_with_index { |patch, i|
        section = "Patch#{i}_#{patch.typename}"
        data = patch.control_points.to_a.map { |pt|
          [ pt.x.to_f, pt.y.to_f, pt.z.to_f ]
        }
        d.set_attribute( ATTR_ID, section, data.inspect )
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