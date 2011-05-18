#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  class SelectionTool
    
    S_NORMAL  = 0
    S_DRAG    = 1
    
    def initialize( editor )
      @editor = editor
      @surface = editor.surface
      
      #@ip_start = Sketchup::InputPoint.new
      #@ip_mouse = Sketchup::InputPoint.new
      
      @selection_rectangle = SelectionRectangle.new( @surface )
      
      # Tool state.
      # Set to S_DRAG when a selection box is active.
      @state = S_NORMAL
      
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
    
    def deactivate(view)
      view.invalidate
    end
    
    def resume(view)
      view.invalidate
      update_ui()
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
        @state = S_DRAG
        @selection_rectangle.end = Geom::Point3d.new( x, y, 0 )
        view.invalidate
      else
        @state = S_NORMAL
        result = @surface.pick_vertices( x, y, view )
        @mouse_over_vertex = !result.empty?
      end
    end
    
    def onLButtonDown( flags, x, y, view )
      @selection_rectangle.start = Geom::Point3d.new( x, y, 0 )
    end
    
    def onLButtonUp(flags, x, y, view)      
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      
      # Pick entities.
      entities = []
      if @state == S_NORMAL
        # Pick priority:
        # * Control Points
        # * Edges
        # * Patches
        vertices = @surface.pick_vertices( x, y, view )
        if vertices.empty?
          edges = @surface.pick_edges( @surface.subdivs, x, y, view )
        else
          edges = []
        end
        entities.concat( vertices )
        entities.concat( edges )
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
      
      @state = S_NORMAL
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
      for entity in @editor.selection
        if entity.is_a?( BezierVertex )
          selected_vertices << entity
        elsif entity.is_a?( BezierEdge )
          selected_edges << entity
        end
      end
      
      unselected_vertices = @surface.vertices - selected_vertices
      unselected_edges = @surface.edges - selected_edges
      
      @surface.draw_internal_grid( view )
      @surface.draw_edges( view, unselected_edges, CLR_EDGE, 2 )
      @surface.draw_edges( view, selected_edges, CLR_CTRL_GRID, 5 )
      @surface.draw_vertices( view, unselected_vertices )
      @surface.draw_vertices( view, selected_vertices, true )
      @surface.draw_vertex_handles( view, selected_vertices )
      
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