#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  module Operations
  
    # Adds a new QuadPatch to the selected BezierEdge.
    #
    # @todo Smarter extrusion of connected edges. Merge entities where possible.
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.add_quadpatch
      model = Sketchup.active_model
      editor = PLUGIN.get_editor( model )
      return false unless editor
      return false unless editor.active?
      return false if editor.selection.empty?
      edges = editor.selection.edges.select { |edge| edge.patches.size == 1 }
      return false if edges.empty?
      model.start_operation( 'Add Quad Patch', true )
      # Extrude edges and merge with other selected edges or newly created 
      # patch edges.
      #puts "\nadd_quadpatch"
      #puts "Edges: #{edges.inspect}"
      stack = edges.dup
      new_edges = []
      until stack.empty?
        edge = stack.shift
        #puts "> Edge: #{edge}"

        # The edge might have been attached to a patch since the initial filter.
        next if edge.patches.size > 1

        #connected_edges = edge.vertices.map { |vertex|
        #  vertex.edges.map { |e| e.vertices }.flatten
        #}.flatten.uniq

        old_patch = edge.patches.first
        target_edges = stack | new_edges #| connected_edges
        #puts "  > Target Edges: #{target_edges.inspect}"
        target_edges.reject! { |e|
          patch = e.patches.first
          #puts "    > Patch: #{patch}"
          shared_edges = ( old_patch.edges & patch.edges ).size
          #puts "    > Shared Edges: #{shared_edges}"
          shared_edges > 0
        }

        new_patch = edge.extrude_quad_patch
        #puts "  > New Patch: #{new_patch}"

        new_patch_edges = new_patch.edges - [edge]

        # Merge Edges
        #target_edges = stack | new_edges #| connected_edges
        source_edges = new_patch.edges - [edge]
        #puts "  > Source Edges: #{source_edges.inspect}"
        #puts "  > Target Edges: #{target_edges.inspect}"
        for vertex in edge.vertices
          #puts "  > Vertex: #{vertex}"
          vertex_edges = vertex.edges
          source_edge = ( source_edges & vertex_edges ).first
          target_edge = ( target_edges & vertex_edges ).first
          next unless source_edge && target_edge
          #puts "    > Source Edge: #{source_edge}"
          #puts "    > Target Edge: #{target_edge}"
          # (!) Hack
          # Currently, to set an edge the positions needs to be the same.
          source_vertex = source_edge.other_vertex( vertex )
          target_vertex = target_edge.other_vertex( vertex )
          source_vertex.position = target_vertex.position

          source_handles = source_edge.handles

          new_patch.set_edge( source_edge, target_edge )
          #puts "    > Target Vertices: #{target_edge.vertices}"
          #puts "    > Target Handles:  #{target_edge.handles}"
          #puts "    > Source Vertices: #{source_edge.vertices}"
          #puts "    > Source Handles:  #{source_edge.handles}"
          #puts "    > New Patch Vertices: #{new_patch.vertices}"
          #puts "    > New Patch Handles:  #{new_patch.handles}"
          target_edge.link( new_patch )
          new_patch_edges.delete( target_edge )
          new_patch_edges.delete( source_edge )
          source_edge.invalidate!
          for handle in source_handles
            handle.invalidate!
          end

          #editor.selection.add( [target_edge, source_edge] )
        end

        new_edges.concat( new_patch_edges )
        new_edges.uniq!

        #editor.selection.clear
        #editor.selection.add( new_edges )
        #break
      end
      editor.surface.update
      model.commit_operation
      true
    end

    
    # Activates the tool to draw a new QuadPatch.
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.draw_quadpatch
      Sketchup.active_model.select_tool( nil )
      Sketchup.active_model.tools.push_tool( CreatePatchTool.new )
    end
    
    
    # @return [Boolean]
    # @since 1.0.0
    def self.convert_selected_to_mesh
      model = Sketchup.active_model
      # Find Bezier Surfaces in selection
      surfaces = model.selection.select { |entity|
        BezierSurface.is?( entity )
      }
      return false if surfaces.empty?
      # Convert all surfaces into normal groups/components.
      model.start_operation( 'Convert to Mesh', true )
      for instance in surfaces
        # Fetch definition and make sure to make the selected instance unique.
        d = TT::Instance.definition( instance )
        if d.count_instances > 1
          instance = instance.make_unique
          d = TT::Instance.definition( instance )
        end
        # Remove "Bezier Surface" from the instance name so it provides a
        # better visual clue that it's no longer a Bezier Surface.
        instance.name = instance.name.gsub( MESH_NAME, 'Editable Mesh' )
        d.name = d.name.gsub( MESH_NAME, 'Editable Mesh' )
        # Remove attributes
        if d.attribute_dictionaries
          d.attribute_dictionaries.delete( ATTR_ID )
        end
      end
      model.commit_operation
      # Clear the selection so there is some kind of user feedback of an event.
      model.selection.clear
      true
    end
    
    
    # @return [Boolean]
    # @since 1.0.0
    def self.update_selected_surface
      model = Sketchup.active_model
      # Find Bezier Surfaces in selection.
      surfaces = model.selection.select { |entity|
        BezierSurface.is?( entity )
      }
      return false if surfaces.empty?
      # Update all selected surfaces.
      model.start_operation( 'Update Surface', true )
      for instance in surfaces
        surface = BezierSurface.load( instance )
        next if surface.nil? # (?) Flag error?
        surface.update
      end
      model.commit_operation
      true
    end
  
  end # module Operations

end # module