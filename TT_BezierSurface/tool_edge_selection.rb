#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  class EdgeSelectionTool
    
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
      Sketchup.status_text = 'Click an edge to select it.'
    end
    
    def activate    
      @editor.selection.clear
      update_ui()
      
      @editor.update_properties # Temp
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
      edges = @surface.pick_edges( @surface.subdivs, x, y, view )
      
      # Update selection
      if key_ctrl && key_shift
        @editor.selection.remove( edges )
      elsif key_ctrl
        @editor.selection.add( edges )
      elsif key_shift
        @editor.selection.toggle( edges )
      else
        @editor.selection.clear
        @editor.selection.add( edges )
      end
      
      view.invalidate
      
      @editor.update_properties # Temp
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
      # Internal grid
      @surface.draw_internal_grid( view )
      # Edges
      selection = @editor.selection
      unselected = @surface.edges.to_a - selection.to_a
      @surface.draw_edges( view, selection, CLR_VERTEX )
      @surface.draw_edges( view, unselected, CLR_CTRL_GRID )
      # Debug
      @surface.draw_edge_directions( view )
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
    
  end # class EdgeSelectionTool

end # module