#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  class BezierHandleTool
    
    def initialize( editor )
      @editor = editor
      @surface = editor.surface
      
      @ip_start = Sketchup::InputPoint.new			
			@ip_mouse = Sketchup::InputPoint.new
      
      # Used by onSetCursor
      @select_ctrl = false
      @select_shift = false
      
      @cursor         = TT::Cursor.get_id(:select)
      @cursor_add     = TT::Cursor.get_id(:select_add)
      @cursor_remove  = TT::Cursor.get_id(:select_remove)
      @cursor_toggle  = TT::Cursor.get_id(:select_toggle)
    end
    
    def update_ui
      Sketchup.status_text = 'Click an handle to manipulate it.'
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
    
    def onLButtonUp(flags, x, y, view)      
      # Get key modifier controlling how the selection should be modified.
      # Using standard SketchUp selection modifier keys.
      key_ctrl = flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
      key_shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      
      # Pick entities
      entities = []
      
      vertices = @surface.pick_vertices( x, y, view )
      if vertices.empty?
        edges = @surface.pick_edges( @surface.subdivs, x, y, view )
      else
        edges = []
      end
      
      entities.concat( vertices )
      entities.concat( edges )
      
      #puts "Selected Vertices: #{vertices.size}"
      #puts "Selected Edges: #{edges.size}"
      
      # Update selection
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
      
      #puts "Selection: #{@editor.selection.size}"
      
      view.invalidate
    end
    
    def onKeyDown(key, repeat, flags, view)
      @select_ctrl  = true if key == COPY_MODIFIER_KEY
      @select_shift = true if key == CONSTRAIN_MODIFIER_KEY
      onSetCursor() # This blocks the VCB. (But "p onSetCursor()" does not.. ? )
      false # The VCB is not blocked as long as onSetCursor isn't the last call.
    end
    
    def onKeyUp(key, repeat, flags, view)
      @select_ctrl  = false if key == COPY_MODIFIER_KEY
      @select_shift = false if key == CONSTRAIN_MODIFIER_KEY
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
    end
    
    def onSetCursor
      if @select_ctrl && @select_shift
        cursor = @cursor_remove
      elsif @select_ctrl
        cursor = @cursor_add
      elsif @select_shift
        cursor = @cursor_toggle
      else
        cursor = @cursor
      end
      UI.set_cursor( cursor )
    end
    
  end # class BezierHandleTool

end # module