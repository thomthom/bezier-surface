#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  class SelectionTool
    
    STATE_NORMAL  = 0
    STATE_DRAG    = 1
    
    def initialize( editor )
      @editor = editor
      @surface = editor.surface
      
      @selection_rectangle = SelectionRectangle.new( @surface )
      
      # Tool state.
      # Set to STATE_DRAG when a selection box is active.
      @state = STATE_NORMAL
      
      # Used by onSetCursor
      @key_ctrl = false
      @key_shift = false
      @mouse_over_vertex = false
      
      @cursor         = TT::Cursor.get_id( :select )
      @cursor_add     = TT::Cursor.get_id( :select_add )
      @cursor_remove  = TT::Cursor.get_id( :select_remove )
      @cursor_toggle  = TT::Cursor.get_id( :select_toggle )
      
      @cursor_vertex        = TT::Cursor.get_id( :vertex )
      @cursor_vertex_add    = TT::Cursor.get_id( :vertex_add )
      @cursor_vertex_remove = TT::Cursor.get_id( :vertex_remove )
      @cursor_vertex_toggle = TT::Cursor.get_id( :vertex_toggle )
    end

    def enableVCB?
      true
    end
    
    def update_ui
      Sketchup.status_text = 'Click an entity to select and manipulate it.'
      Sketchup.vcb_label = 'Subdivisions'
      Sketchup.vcb_value = @surface.subdivs
    end
    
    def activate    
      @editor.selection.clear
      update_ui()
    end
    
    def deactivate( view )
      view.invalidate
    end
    
    def resume( view )
      view.invalidate
      update_ui()
    end
    
    def getMenu( menu )
      m = menu.add_item( 'Select All' ) { puts '01' }
      menu.set_validation_proc( m ) { MF_GRAYED }
      
      m = menu.add_item( 'Select None' ) { puts '02' }
      menu.set_validation_proc( m ) { MF_GRAYED }
      
      m = menu.add_item( 'Invert Selection' ) { puts '03' }
      menu.set_validation_proc( m ) { MF_GRAYED }
      
      @editor.context_menu( menu )
    end
    
    def onUserText( text, view )
      subdivs = text.to_i
      if SUBDIVS_RANGE.include?( subdivs )
        @editor.change_subdivisions( subdivs )
      else
        UI.beep
      end
      view.invalidate
      update_ui()
    end
    
    def onMouseMove( flags, x, y, view )
      if flags & MK_LBUTTON == MK_LBUTTON
        @state = STATE_DRAG
        @selection_rectangle.end = Geom::Point3d.new( x, y, 0 )
        view.invalidate
      else
        @state = STATE_NORMAL
        result = @surface.pick_vertices( x, y, view )
        @mouse_over_vertex = !result.empty?
      end
    end
    
    def onLButtonDown( flags, x, y, view )
      @selection_rectangle.start = Geom::Point3d.new( x, y, 0 )
    end
    
    def onLButtonUp( flags, x, y, view )      
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      
      # Pick entities.
      entities = []
      if @state == STATE_NORMAL
        # Control Points
        picked = @surface.pick_vertices( x, y, view )
        entities.concat( picked )
        # Edges
        if entities.empty?
          picked = @surface.pick_edges( @surface.subdivs, x, y, view )
          entities.concat( picked )
        end
        # Patch
        if entities.empty?
          picked = @surface.pick_patch( x, y, view )
          entities << picked if picked
        end
      else
        availible = @surface.vertices + @surface.edges
        entities = @selection_rectangle.selected_entities( view, availible )
      end
      
      # Update selection.
      if key_ctrl && key_shift
        @editor.selection.remove( entities )
      elsif key_ctrl
        @editor.selection.add( entities )
      elsif key_shift
        @editor.selection.toggle( entities )
      else
        @editor.selection.clear
        @editor.selection.add( entities )
      end
      
      @editor.update_properties
      
      @state = STATE_NORMAL
      @selection_rectangle.reset
      view.invalidate
    end
    
    def onKeyDown(key, repeat, flags, view)
      @key_ctrl  = true if key == COPY_MODIFIER_KEY
      @key_shift = true if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    def onKeyUp(key, repeat, flags, view)
      @key_ctrl  = false if key == COPY_MODIFIER_KEY
      @key_shift = false if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor()
      false
    end
    
    def draw( view )
      tr = view.model.edit_transform
      
      selected_vertices = []
      selected_edges = []
      selected_patches = []
      for entity in @editor.selection
        if entity.is_a?( BezierVertex )
          selected_vertices << entity
        elsif entity.is_a?( BezierEdge )
          selected_edges << entity
        elsif entity.is_a?( BezierPatch )
          selected_patches << entity
        end
      end
      
      unselected_vertices = @surface.vertices - selected_vertices
      unselected_edges = @surface.edges - selected_edges
      
      # Get selected vertices and selected entities' vertices. Display handles
      # for each vertex.
      edge_vertices = selected_edges.map { |edge| edge.vertices }
      edge_vertices.flatten!
      patch_vertices = selected_patches.map { |patch| patch.vertices }
      patch_vertices.flatten!
      active_vertices = selected_vertices + edge_vertices + patch_vertices
      
      # Get manual interiorpoints
      interior = []
      for patch in @surface.patches
        next if patch.automatic?
        interior.concat( patch.interior_points )
      end
      interior.map! { |cpt| cpt.position }
      
      # Draw patches last because it uses transparent colour. SketchUp seem to
      # cull out any opaque drawing that happens after transparent drawing.
      @surface.draw_internal_grid( view )
      @surface.draw_edges( view, unselected_edges, CLR_EDGE, 2 )
      @surface.draw_edges( view, selected_edges, CLR_EDGE_SELECTED, 5 )
      @surface.draw_vertices( view, unselected_vertices )
      @surface.draw_vertices( view, selected_vertices, true )
      @surface.draw_vertex_handles( view, active_vertices )
      @surface.draw_markers( view, interior, 'black' )
      @surface.draw_patches( view, selected_patches )
      
      @selection_rectangle.draw( view )
    end
    
    def onSetCursor
      if @key_ctrl && @key_shift
        cursor = (@mouse_over_vertex) ? @cursor_vertex_remove : @cursor_remove
      elsif @key_ctrl
        cursor = (@mouse_over_vertex) ? @cursor_vertex_add : @cursor_add
      elsif @key_shift
        cursor = (@mouse_over_vertex) ? @cursor_vertex_toggle : @cursor_toggle
      else
        cursor = (@mouse_over_vertex) ? @cursor_vertex : @cursor
      end
      UI.set_cursor( cursor )
    end
    
  end # class SelectionTool

end # module