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
      @subdivs = SUBDIVS_DEFAULT
    end
    
    # Because very large values for subdivision will cause SketchUp to
    # potentially become unresponsive for a long time while calculating
    # this property will raise an exception if the value is out of bounds.
    #
    # The UI element allowing this property to be set should also perform
    # validation, but this method acts as an extra security in case a validation
    # bug should occur.
    #
    # @return [Numeric]
    # @since 1.0.0
    def subdivs=( value )
      unless value.is_a?( Numeric )
        raise ArgumentError, 'Argument not numeric.'
      end
      unless SUBDIVS_RANGE.include?( value )
        raise ArgumentError, 'Invalid subdivision range.'
      end
      @subdivs = value
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
    
    # Data Format Version: 1.0.2
    #
    # Reloads the bezier patch data from the attribute dictionary of the
    # assosiated instance.
    #
    # Use after undo is detected to corrently rebuild the geometry.
    #
    # @return [BezierSurface|Nil]
    # @since 1.0.0
    def reload
      TT.debug( 'BezierSurface.reload' )
      debug_time_start = Time.now
      
      # Verify mesh definition
      d = TT::Instance.definition( @instance )
      raise 'Invalid definition' if d.nil?
      
      # Verify version compatibility
      mesh_version = d.get_attribute( ATTR_ID, ATTR_VERSION )
      mesh_version = TT::Version.new( mesh_version )
      if mesh_version < MESH_VERSION
        raise 'Unsupported old mesh format.'
      end
      
      # Read properties
      self.subdivs = d.get_attribute( ATTR_ID, ATTR_SUBDIVS )
      
      # Read Points
      positions = d.get_attribute( ATTR_ID, ATTR_POSITIONS )
      # (!) Validate array
      for point in positions
        # (!) Validate Point3d
        point.extend( TT::Point3d_Ex )
      end
      TT.debug "> positions: #{positions.size} (#{positions.nitems})"
      unless positions.size == positions.nitems
        raise TypeError, 'Invalid Point3d data'
      end
      
      # Read ControlPoints
      cp_index = {}
      # Vertices
      data = d.get_attribute( ATTR_ID, ATTR_VERTICES )
      data.each { |properties_data|
        prop = TT.array_to_hash( properties_data )
        index = prop[ 'Position' ]
        cpt = BezierVertex.new( self, positions[ index ] )
        cp_index[ index ] = cpt
      }
      # Handles
      data = d.get_attribute( ATTR_ID, ATTR_HANDLES )
      data.each { |properties_data|
        prop = TT.array_to_hash( properties_data )
        index = prop[ 'Position' ]
        cpt = BezierHandle.new( self, positions[ index ] )
        cpt.linked = prop[ 'Linked' ]
        cp_index[ index ] = cpt
      }
      # InteriorPoint
      data = d.get_attribute( ATTR_ID, ATTR_INTERIORPOINTS )
      data.each { |properties_data|
        prop = TT.array_to_hash( properties_data )
        index = prop[ 'Position' ]
        cpt = BezierInteriorPoint.new( self, positions[ index ] )
        cp_index[ index ] = cpt
      }
      # Index ControlPoints to match positions
      cpoints = []
      for index in ( 0...positions.size )
        cpoints << cp_index[ index ]
      end
      TT.debug "> controlpoints: #{cpoints.size} (#{cpoints.nitems})"
      unless cpoints.size == cpoints.nitems
        raise TypeError, 'Invalid Control Point data'
      end
      unless cpoints.size == positions.size
        raise TypeError, 'Missing Control Point data'
      end
      
      # Read Edges
      edge_data = d.get_attribute( ATTR_ID, ATTR_EDGES )     
      edge_sets = []
      for indexes in edge_data
        points = indexes.map { |index| positions[index] }
        unless points.nitems == 4
          raise 'Invalid control points.'
        end
        edge = BezierEdge.new( self, points )
        edge_sets << edge
      end
      TT.debug "> edge_sets: #{edge_sets.size} (#{edge_sets.nitems})"
      unless edge_sets.size == edge_sets.nitems
        raise TypeError, 'Invalid Edge data'
      end
      
      # Read Patches
      valid_patches = %w{ QuadPatch }
      raw_patches = d.get_attribute( ATTR_ID, ATTR_PATCHES )
      for raw_patch_data in raw_patches
        patch_data = TT.array_to_hash(  raw_patch_data )
        
        # Read Properties
        type            = patch_data[ 'Type' ]
        edgeuses        = patch_data[ 'EdgeUses' ]
        interior_points = patch_data[ 'InteriorPoints' ]
        automatic       = patch_data[ 'Automatic' ]
        
        # The patch type string is eval'ed into a Class object which is then
        # used to load the patch data. The patch is left with the resonsibility
        # of handling the data loading.
        unless valid_patches.include?( type )
          raise "Invalid patch type: #{type}"
        end
        patchtype = eval( type )
        
        # Interior Points
        interior_points.map! { |index| positions[index] }
        unless interior_points.nitems == 4
          raise 'Invalid interior points'
        end
        
        # EdgeUses
        edgeuses_set = []
        for raw_edgeuse in edgeuses
          edgeuse_data = TT.array_to_hash( raw_edgeuse )
          # Read Properties
          edge_index    = edgeuse_data[ 'Edge' ]
          edge_reversed = edgeuse_data[ 'Reversed' ]
          # Recreate objects
          edge = edge_sets[edge_index]
          edgeuses_set << BezierEdgeUse.new( nil, edge, edge_reversed ) # Temp
        end
        TT.debug "  > edgeuses_set: #{edgeuses_set.size} (#{edgeuses_set.nitems})"
        unless edgeuses_set.size == edgeuses_set.nitems
          raise TypeError, 'Invalid EdgeUse data'
        end
        
        # Add patch
        patch = patchtype.restore( self, edgeuses_set, interior_points ) # (!) hash
        patch.automatic = automatic
        self.add_patch( patch )
      end
      
      TT.debug( "> Loaded in #{Time.now-debug_time_start}s" )
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
      raise ArgumentError, 'Not a BezierPatch.' unless patch.is_a?( BezierPatch )
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
      #TT.debug "\nBezierSurface.control_points"
      pts = []
      for patch in @patches
        pts.concat( patch.control_points.to_a )
      end
      #TT.debug pts.size
      pts.uniq!
      #TT.debug pts.size
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
    
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_control_edges( view, edges )
      return false if edges.empty?
      tr = view.model.edit_transform
      view.line_width = CTRL_GRID_BORDER_WIDTH
      view.line_stipple = ''
      view.drawing_color = CLR_CTRL_GRID
      for edge in edges
        screen_points = edge.positions.map { |point|
          view.screen_coords( point.transform(tr) )
        }
        view.draw2d( GL_LINE_STRIP, screen_points )
      end
      true
    end
    
    # Draws the control grid structure for all the paches in the surface.
    #
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_control_grid(view)
      for patch in @patches
        patch.draw_control_grid_fill( view )
      end
      # Borders
      draw_control_edges( view, edges )
      # Internal Grid
      view.drawing_color = CLR_CTRL_GRID
      view.line_width = CTRL_GRID_LINE_WIDTH
      view.line_stipple = '-'
      for patch in @patches
        patch.draw_internal_control_grid( view )
      end
      nil
    end
    
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_control_handles( view )
      return false if edges.empty?
      
      control_points = []
      handle_points = []
      handle_lines = []
      internal_points = []

      tr = view.model.edit_transform
      for edge in edges
        world_points = edge.positions.map { |point|
          point.transform(tr)
        }
        
        control_points << world_points[0]
        control_points << world_points[3]
        
        handle_points << world_points[1]
        handle_points << world_points[2]
        
        handle_lines.concat( world_points )
      end
      
      for patch in patches
        patch.interior_points.each { |control_point|
          internal_points << control_point.position.transform(tr)
        }
      end
      
      view.line_width = 2
      view.line_stipple = ''
      
      # Handle Lines
      view.drawing_color = 'orange'
      view.draw( GL_LINES, handle_lines )
      
      # Handle Points
      view.line_width = 2
      #view.draw_points( handle_points, VERTEX_SIZE, TT::POINT_X, 'green' )
      draw_circles( view, handle_points, 'green' )
      
      # Interior Points
      view.line_width = 2
      #view.draw_points( internal_points, VERTEX_SIZE, TT::POINT_CROSS, 'black' )
      draw_markers( view, internal_points, 'black', 6 )
      
      # Control Points
      view.line_width = CTRL_GRID_BORDER_WIDTH
      view.drawing_color = CLR_VERTEX
      view.draw_points( control_points, VERTEX_SIZE, TT::POINT_OPEN_SQUARE, CLR_VERTEX )
      
      # Account for SU bug where draw_points kills the next draw operation.
      view.draw2d( GL_LINES, [-10,-10,-10], [-11,-11,-11] )
      
      true
    end
    
    # Draws the internal subdivided structure for all the paches in the surface.
    #
    # @param [Sketchup::View] view
    # @param [Boolean] preview
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_internal_grid(view, preview = false)
      for patch in @patches
        if preview
          patch.draw_internal_grid( preview, view )
        else
          patch.draw_internal_grid( @subdivs, view )
        end
      end
      nil
    end
    
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_edges( view, edges, color = CLR_EDGE, width = 5, preview = false )
      return false if edges.empty?
      tr = view.model.edit_transform
      subdivs = (preview) ? preview : @subdivs
      
      view.line_width = width
      view.line_stipple = ''
      view.drawing_color = color
      for edge in edges
        view.draw( GL_LINE_STRIP, edge.segment( subdivs, tr ) )
      end
      true
    end
    
    # <debug>
    def draw_edge_directions( view )
      tr = view.model.edit_transform
      subdivs = @subdivs
      for patch in @patches
        v1 = patch.edges[0].direction
        v2 = patch.edges[1].direction
        normal = v1 * v2
        for edge in patch.edges
          pts = edge.segment( subdivs, tr )
          
          d = edge.direction
          if edge.reversed_in?( patch )
            view.drawing_color = 'purple'
            #d = pts[-1].vector_to( pts[-2] )
            d.reverse!
            pt = pts[-2]
          else
            view.drawing_color = 'green'
            #d = pts[0].vector_to( pts[1] )
            #d = pts[0].vector_to( pts[1] )
            pt = pts[1]
          end
          
          #v = d * Z_AXIS
          v = d * normal
          #v = d.axes.x
          view.line_width = 4
          view.line_stipple = ''
          
          size = view.pixels_to_model( 25, pt )
          o = pt.offset( v, size )
          
          view.draw_line( pt, o )
        end
      end
    end
    # </debug>
    
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw_control_points( view, selected = [] )
      tr = view.model.edit_transform
      # Prepare viewport
      view.line_stipple = ''
      view.line_width = 2
      # Prepare points
      #unselected = (control_points - selected).map { |pt| pt.transform(tr) }
      all_points = control_points.map { |cpt| cpt.position.transform(tr) }
      selected = selected.map { |cpt| cpt.position.transform(tr) }
      # Drawing
      #unless unselected.empty?
      #  view.draw_points( unselected, VERTEX_SIZE, TT::POINT_OPEN_SQUARE, CLR_VERTEX )
      #end
      view.draw_points( all_points, VERTEX_SIZE, TT::POINT_OPEN_SQUARE, CLR_VERTEX )
      unless selected.empty?
        view.draw_points( selected, VERTEX_SIZE, TT::POINT_FILLED_SQUARE, CLR_VERTEX )
      end
      # Account for SU bug where draw_points kills the next draw operation.
      view.draw2d( GL_LINES, [-10,-10,-10], [-11,-11,-11] )
    end
    
    # @since 1.0.0
    def draw_circles( view, points, color, size = VERTEX_SIZE, line_width = 2 )
      vector = view.camera.direction.reverse
      radius = size / 2.0
      
      view.line_stipple = ''
      view.line_width = line_width
      view.drawing_color = color
      for point in points
        screen_size = view.pixels_to_model( radius, point )
        circle_points = TT::Geom3d.circle( point, vector, screen_size, 8 )
        view.draw( GL_LINE_LOOP, circle_points )
      end
    end
    
    # @since 1.0.0
    def draw_markers( view, points, color, size = VERTEX_SIZE, line_width = 2 )
      vector = view.camera.direction.reverse
      vx1 = view.camera.xaxis
      vx2 = vx1.reverse
      vy1 = view.camera.yaxis
      vy2 = vy1.reverse
      radius = size / 2.0
      
      view.line_stipple = ''
      view.line_width = line_width
      view.drawing_color = color
      for point in points
        screen_size = view.pixels_to_model( radius, point )
        marker_points = []
        marker_points << point.offset( vx1, screen_size )
        marker_points << point.offset( vx2, screen_size )
        marker_points << point.offset( vy1, screen_size )
        marker_points << point.offset( vy2, screen_size )
        view.draw( GL_LINES, marker_points )
      end
    end
    
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
      
      # <debug>
      unless pts.length == vertices.length
        TT.debug( 'mesh_vertices' )
        TT.debug( "> Points: #{pts.length}" )
        TT.debug( "> Vertices: #{vertices.length}" )
      end
      # </debug>
      
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
      entities = []
      vectors = []
      vertices.each_with_index { |v,i|
        vector = v.position.vector_to( positions[i] )
        if vector.valid?
          entities << v
          vectors << vector
        end
      }
      # (!) ensure entities has same length as vectors
      d = TT::Instance.definition( @instance )
      d.entities.transform_by_vectors( entities, vectors )
      true
    end
    
    # @return [String]
    # @since 1.0.0
    def inspect
      id = TT.object_id_hex( self )
      "#<#{self.class.name}:#{id} - Subdivs: #{@subdivs} - Patches: #{@patches.size}>"
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
    
    # Data Format Version: 1.0.2
    #
    # Updates the attribute dictionary with the BezierSurface data.
    #
    # @return [Boolean]
    # @since 1.0.0
    def update_attributes
      TT.debug( 'BezierSurface.update_attributes' )
      debug_time_start = Time.now
      
      # ### DATA FORMAT ###
      #
      # Data is stored in an dictionary named: ATTR_ID ('TT_Mesh')
      #   In case of future alternative mesh types this attribute is used to
      #   identify the type of mesh. This is to reduce the number of dictionary
      #   names used.
      #
      # KEY: ATTR_TYPE ('Type')
      #   VALUE: MESH_TYPE ('BezierSurface')
      #
      #
      # KEY: ATTR_VERSION ('Version')
      #   VALUE: MESH_VERSION.to_s ('n.n.n')
      #
      #   Identifies the data format version.
      #
      #
      # KEY: ATTR_SUBDIVS ('Subdivs')
      #   VALUE: n (Integer)
      #
      #   Number of subdivisions.
      #
      #
      # KEY: ATTR_POSITIONS ('Positions')
      #   VALUE: Array< Point3d >
      #
      #   Array of 3d positions for each control point in the mesh.
      #   Array is 1:1 mapping of surface.control_points.
      #
      #
      # KEY: 'Vertices'
      #   VALUE: Array< {
      #     'Position' => POINT_INDEX,
      #     'Links' => �ARRAY_LINKS
      #   }.to_a >
      #
      #   Array of BezierVertex objects mapped to a property hash.
      #   The property hash is converted to an array before it's stored in the
      #   dictionary because SketchUp store Hash object as Nil.
      #
      #
      # KEY: 'Handles'
      #   VALUE: Array< {
      #     'Position' => POINT_INDEX,
      #     'Links' => �ARRAY_LINKS
      #   }.to_a >
      #
      #   Array of BezierHandle objects mapped to a property hash.
      #
      #
      # KEY: 'InteriorPoints'
      #   VALUE: Array< {
      #     'Position' => POINT_INDEX,
      #     'Links' => �ARRAY_LINKS
      #   }.to_a >
      #
      #   Array of BezierInteriorPoint objects mapped to a property hash.
      #
      #
      # �ARRAY_LINKS
      #
      #
      #
      # --- OLD FORMAT ---
      #
      # SURFACE
      # Surface properties written to attribute:
      # * Type ( BezierSurface )
      # * Version
      # * Subdivisions
      # * Number of Control Points
      # * Number of Bezier Edges
      # * Number of Bezier Patches
      #
      # Indexes all control points in the surface into a quick-access hash.
      # Edges are converted into sets of point-indexes.
      # Edges are also indexed.
      # 
      # CONTROL POINTS
      # All the control points in the surface is added to a hash lookup table.
      # Ex: hash { BezierControlPoint => index, ... }
      #
      # POSITIONS
      # Attribute key: 'Positions'
      # Content: Array<Geom::Point3d>
      # The positions array is mapped from surface.control_points - 1:1 mapping
      # of all the BezierControlPoints in the surface.
      #
      # VERTEX
      # Attribute key: 'Vertices'
      # Content:
      # Array<
      #   {
      #     'Position' => POINT3D_INDEX,
      #     'Links' => Array<
      #       {
      #         'Handles' => Array<INDEXES>
      #       }
      #     >
      #   }
      # >
      #
      # EDGES
      # The edges is also indexed in a lookup table.
      # Ex: hash = { point3d => index, ... }
      #
      # Then the edges are turned into arrays of control point indexes.
      # Ex: edge = [ cpt1, cpt2, cpt3, cpt4 ]
      #
      # PATCHES
      # Each patch is stored to a separate attribute dictionary because they
      # require additional attributes. Separate dictionaries seems like an
      # easy method of managing the data.
      #
      # PATCH
      # Each patch contains the patch properties:
      # * Type ( QuadPatch | TriPatch | ... )
      # * EdgeUse count
      # * EdgeUse objects
      # * Interior Points - Required Control Points not part of the edges.
      #
      # VALIDATION
      # Data size attributes is also stored for data validation. Check that
      # loaded objects match the indicated size.
      #
      # NOTES
      # (?) Should patches be written into the main dictionary? Would it be
      #     'cleaner'?
      
      d = TT::Instance.definition( @instance )
      
      # Remove old data
      if d.attribute_dictionaries
        d.attribute_dictionaries.delete( ATTR_ID )
      end
      
      # Write Surface data
      d.set_attribute( ATTR_ID, ATTR_TYPE, MESH_TYPE )
      d.set_attribute( ATTR_ID, ATTR_VERSION, MESH_VERSION.to_s )
      d.set_attribute( ATTR_ID, ATTR_SUBDIVS, @subdivs )
      
      ### Control Points
      # Control points are added to a hash table for quick indexing and their
      # positions are gathered and stored.
      cpoints = control_points() # Array<BezierControlPoint>
      point_index = {}  # Lookup hash for quick cpoint => position indexing.
      point_data = []   # 3D point data set. Array<[x,y,z]>
      cpoints.each_with_index { |control_point, index|
        # Index Control point
        point_index[ control_point ] = index
        # Add point to dataset
        point_data << control_point.position
      }
      d.set_attribute( ATTR_ID, ATTR_POSITIONS, point_data )
      
      TT.debug( "> Points written #{Time.now-debug_time_start}s" )
      
      # BezierControlPoints relationship and properties
      cpoint_data = {
        BezierVertex => [],
        BezierHandle => [],
        BezierInteriorPoint => []
      }
      keys = {
        BezierVertex => 'Vertices',
        BezierHandle => 'Handles',
        BezierInteriorPoint => 'InteriorPoints'
      }
      for control_point in cpoints
        # Generic properties
        properties = {
          'Position' => point_index[ control_point ]
        }
        # BezierHandle
        if control_point.is_a?( BezierHandle )
          properties['Linked'] = control_point.linked?
        end
        #
        cpoint_data[ control_point.class ] << properties.to_a
      end
      d.set_attribute( ATTR_ID, ATTR_VERTICES, cpoint_data[ BezierVertex ] )
      d.set_attribute( ATTR_ID, ATTR_HANDLES, cpoint_data[ BezierHandle ] )
      d.set_attribute( ATTR_ID, ATTR_INTERIORPOINTS, cpoint_data[ BezierInteriorPoint ] )
      
      TT.debug( "> Control Points written #{Time.now-debug_time_start}s" )
      
      ### Edges
      edge_data = []
      edge_indexes = {}   # Lookup hash for quick indexing
      TT.debug '> Edges'
      edges.each_with_index { |edge, index|
        # Index Edge
        edge_indexes[ edge ] = index
        # Add edge to dataset. Array of control points.
        indexes = edge.control_points.map { |cpoint| point_index[cpoint] }
        edge_data << indexes
      }
      d.set_attribute( ATTR_ID, ATTR_EDGES, edge_data )
      
      TT.debug( "> Edges written #{Time.now-debug_time_start}s" )
      
      ### Patches
      patch_data = []
      for patch in patches
        # Edgeuses
        edgeuses_data = []
        for edgeuse in patch.edgeuses
          edgeuses_data << {
            'Edge'      => edge_indexes[ edgeuse.edge ],
            'Reversed'  => edgeuse.reversed?
          }.to_a
        end
        # Interior Points
        interior_points = patch.interior_points.map { |control_point|
          point_index[control_point]
        }.to_a
        # Patch Data
        patch_data << {
          'Type'            => patch.typename,
          'EdgeUses'        => edgeuses_data,
          'InteriorPoints'  => interior_points,
          'Automatic'       => patch.automatic?
        }.to_a
      end
      d.set_attribute( ATTR_ID, ATTR_PATCHES, patch_data )
      
      TT.debug( "> Patches written #{Time.now-debug_time_start}s" )
      
      TT.debug( "> Written in #{Time.now-debug_time_start}s" )
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
      TT.debug( 'BezierSurface.update_mesh' )
      d = TT::Instance.definition( @instance )
      points = count_mesh_points( subdivs )
      polygons = count_mesh_polygons( subdivs )
      mesh = Geom::PolygonMesh.new( points, polygons )
      TT.debug( '> Adding patches...' )
      for patch in @patches
        patch.add_to_mesh( mesh, subdivs, transformation )
      end
      TT.debug( '> Clear and fill...' )
      debug_time_start = Time.now
      d.entities.clear!
      d.entities.fill_from_mesh( mesh, true, TT::MESH_SOFT_SMOOTH )
      TT.debug( "> Filled in #{Time.now-debug_time_start}s" )
    end
    
  end # class BezierSurface

end # module