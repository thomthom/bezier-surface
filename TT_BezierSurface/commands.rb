#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  # Adds a new QuadPatch to the selected BezierEdge.
  #
  # @return [Boolean]
  # @since 1.0.0
  def self.add_quadpatch
    model = Sketchup.active_model
    editor = self.get_editor( model )
    return false unless editor
    return false unless editor.active?
    return false unless editor.selection.size == 1
    edge = editor.selection[0]
    return false unless edge.is_a?( BezierEdge )
    edge.extrude_quad_patch
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

end # module