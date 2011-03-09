#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::BPatch
  
  class BezierSurface
    
    attr_reader( :patches, :instance )
    attr_accessor( :subdivs )
    
    def initialize( instance )
      @instance = instance
      @patches = []
      @subdivs = 6
    end
    
    def self.is?( instance )
      d = TT::Instance.definition( instance )
      return false if d.nil?
      mesh_type = d.get_attribute( ATTR_ID, 'Type' )
      mesh_type == MESH_TYPE
    end
    
    def self.load( instance )
      TT.debug( 'BezierSurface.load' )
      return nil unless self.is?( instance )
      surface = self.new( instance )
      surface.reload
    end
    
    def reload
      TT.debug( 'BezierSurface.reload' )
      d = TT::Instance.definition( @instance )
      self.subdivs = d.get_attribute( ATTR_ID, 'Subdivs' )
      # Load Patches
      @patches.clear
      attr = d.attribute_dictionaries[ ATTR_ID ]
      attr.each { |key, value|
        test = key.match(/Patch(\d+)_(\w+)/)
        next unless test
        patchtype = eval( test[2] )
        data = eval( value )
        points = data.map { |pt| Geom::Point3d.new( pt ) }
        self.add_patch( patchtype.new( points ) )
      }
      self
    end
    
    def update( transformation )
      TT.debug( 'Updating Bezier Surface...' )
      Sketchup.status_text = 'Updating Bezier Surface...'
      update_mesh( @subdivs, transformation )
      update_attributes()
    end
    
    def preview( transformation, subdivs = 4 )
      #TT.debug( 'Preview Bezier Surface...' )
      Sketchup.status_text = 'Preview Bezier Surface...'
      update_mesh( subdivs, transformation )
    end
    
    def add_patch( patch )
      raise ArgumentError, 'Not a BezierPatch.' unless patch.is_a?(BezierPatch)
      @patches << patch
    end
    
    # Is not accurate - does not take into account patches that share points.
    def count_mesh_points( subdivs )
      count = 0
      @patches.each { |patch|
        count += patch.count_mesh_points( subdivs )
      }
      count
    end
    
    # Is not accurate - does not take into account patches that share polygon
    # edges. Also - if the mesh is not always triangulated there might be less
    # polygons.
    def count_mesh_polygons( subdivs )
      count = 0
      @patches.each { |patch|
        count += patch.count_mesh_polygons( subdivs )
      }
      count
    end
    
    # Returns the control points for all the paches in the surface.
    def control_points
      pts = []
      @patches.each { |patch|
        pts.concat( patch.control_points.to_a )
      }
      pts.uniq!
      pts
    end
    
    def pick_control_points(x, y, view)
      picked = []
      @patches.each { |patch|
        points = patch.pick_control_points( x, y, view )
        picked.concat( points ) unless points.nil?
      }
      #( picked.empty? ) ? nil : picked.uniq
      picked.uniq
    end
    
    def pick_edges(subdivs, x, y, view)
      picked = []
      @patches.each { |patch|
        points = patch.pick_edges( subdivs, x, y, views )
        picked.concat( points ) unless points.nil?
      }
      #( picked.empty? ) ? nil : picked.uniq
      picked.uniq
    end
    
    def draw_control_grid(view)
      @patches.each { |patch|
        patch.draw_control_grid( view )
      }
    end
    
    def draw_grid(view, preview = false)
      @patches.each { |patch|
        if preview
          patch.draw_grid( preview, view )
        else
          patch.draw_grid( @subdivs, view )
        end
      }
    end
    
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
    
    def mesh_points( subdivs, transformation )
      pts = []
      @patches.each { |patch|
        pts.concat( patch.mesh_points( subdivs, transformation ).to_a )
      }
      pts.uniq! # (!) custom uniq to only return uniqe 3d positions.
      pts
    end
    
    # Returns vertices in the same order as mesh_points.
    def mesh_vertices( subdivs, transformation )
      d = TT::Instance.definition( @instance )
      pts = mesh_points( subdivs, transformation )
      vs = raw_mesh_vertices()
      
      #pts.each { |pt| p pt }
      #puts '--'
      #vs.each { |v| p v.position }
      #p pts.length
      #p pts
      #p vs.length
      #p vs
      
      patch_vertices = []
      pts.each { |pt|
        vertex = vs.find { |v| v.position == pt }
        patch_vertices << vertex
        vs.delete( vertex )
      }
      patch_vertices
    end
    
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
    end
    
    private
    
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
    
    def update_attributes
      d = TT::Instance.definition( @instance )
      d.set_attribute( ATTR_ID, 'Type', MESH_TYPE )
      d.set_attribute( ATTR_ID, 'Subdivs', @subdivs )
      @patches.each_with_index { |patch, i|
        section = "Patch#{i}_#{patch.typename}"
        data = patch.control_points.to_a.map { |pt|
          [ pt.x.to_f, pt.y.to_f, pt.z.to_f ]
        }
        d.set_attribute( ATTR_ID, section, data.inspect )
      }
    end
    
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