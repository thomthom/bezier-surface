#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # @since 1.0.0
  class MergeTool

    # @since 1.0.0
    def initialize( editor )
      @editor = editor
      @surface = editor.surface

      @source_edge = @editor.selection.find { |e|
        e.is_a?( BezierEdge ) && e.patches.size == 1
      }
      @target_edge = nil

      @editor.selection.clear
      @editor.selection.add( @source_edge ) if @source_edge

      @mouse_edge = nil
    end

    # Updates the statusbar and VCB.
    #
    # @return [Nil]
    # @since 1.0.0
    def update_ui
      if @source_edge
        Sketchup.status_text = 'Pick target edge.'
      else
        Sketchup.status_text = 'Pick source edge you want to merge with a target.'
      end
      nil
    end

    # Called by BezierEditor when the selection or geometry has updated.
    # The viewport graphics then needs updating.
    #
    # @return [Nil]
    # @since 1.0.0
    def refresh_viewport
      #puts 'MergeTool.refresh_viewport'
      #update_gizmo()
      nil
    end

    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#activate
    #
    # @since 1.0.0
    def activate
      update_ui()
      @editor.refresh_viewport
    end

    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#deactivate
    #
    # @since 1.0.0
    def deactivate( view )
      view.invalidate
    end

    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#resume
    #
    # @since 1.0.0
    def resume( view )
      update_ui()
      @editor.refresh_viewport
      view.invalidate
    end

    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#getMenu
    #
    # @since 1.0.0
    def getMenu( menu, *args )
      # The *args is needed for SU2015's change to this method where it passes
      # more arguments if the arity isn't 1. Because OperatorManager relays
      # events using the splat operator the arity is -1.
      @editor.context_menu( menu )
    end

    # @see https://developers.google.com/sketchup/docs/ourdoc/tool#onCancel
    #
    # @since 1.0.0
    def onCancel( reason, view )
      # 0: the user canceled the current operation by hitting the escape key.
      # 1: the user re-selected the same tool from the toolbar or menu.
      # 2: the user did an undo while the tool was active.
      @source_edge = nil
      @editor.selection.clear
      view.invalidate
    end

    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onMouseMove
    #
    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      picked_edges = @surface.pick_edges( @surface.subdivs, x, y, view )
      @mouse_edge = picked_edges.find { |edge|
        source_edges = ( @source_edge ) ? @source_edge.patches.first.edges : []
        edge.patches.size == 1 && !source_edges.include?( edge )
      }
      view.invalidate
    end

    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#onLButtonUp
    #
    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      # Ensure an edge was picked.
      unless @mouse_edge
        UI.beep
        return
      end

      if @source_edge
        merge_edges( @source_edge, @mouse_edge )
        @source_edge = nil
      else
        @source_edge = @mouse_edge
        @editor.selection.clear
        @editor.selection.add( @source_edge )
      end

      update_ui()
      @editor.refresh_viewport
      view.invalidate
    end

    # @see http://code.google.com/apis/sketchup/docs/ourdoc/tool.html#draw
    #
    # @since 1.0.0
    def draw( view )
      @editor.draw_cache.render

      # Draw edge under cursor
      if @mouse_edge
        view.line_stipple = ''
        view.line_width = 6
        view.drawing_color = [128,255,128]
        segment = @mouse_edge.segment( @surface.subdivs, view.model.edit_transform )
        view.draw( GL_LINE_STRIP, segment )
      end
    end

    private

    def merge_edges( source_edge, target_edge )
      @editor.model.start_operation( 'Merge Edges', true )
      # Find nearest start vertex.
      target_start = target_edge.start.position
      source_start = source_edge.vertices.sort { |a,b|
        d1 = a.position.distance( target_start )
        d2 = b.position.distance( target_start )
        d1 <=> d2
      }.first.position
      # Sort new positions to match target edge orientation.
      new_points = target_edge.positions
      new_points.reverse! if source_start != source_edge.start
      # Initial rough move - moves all related control points.
      source_edge.start.move!( new_points[0] )
      source_edge.end.move!( new_points[3] )
      # Set new precise positions - makes the source edge match 100% the target.
      source_edge.control_points = new_points
      # Merge edge.
      target_patch = target_edge.patches.first
      source_patch = source_edge.patches.first
      source_patch.replace_edge( source_edge, target_edge )
      # Update mesh.
      @surface.update
      @editor.model.commit_operation
      @editor.refresh_viewport
    end

  end # class SelectionTool

end # module
