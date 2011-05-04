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
  
  
  # @return [Boolean]
  # @since 1.0.0
  def self.convert_selected_to_mesh
    # Verify selection.
    model = Sketchup.active_model
    return false if model.selection.length != 1
    instance = model.selection[0]
    return false unless BezierSurface.is?( instance )
    # Fetch definition and make sure to make the selected instance unique.
    d = TT::Instance.definition( instance )
    if d.count_instances > 1
      instance = instance.make_unique
      d = TT::Instance.definition( instance )
    end
    # Remove names
    # (?) Check for "Bezier Surface" in case user set custom name?
    instance.name = ''
    d.name = 'Editable Mesh'
    # Fetch number of patches. The number of patches is required
    # because there is an attribute dictionary for each patch.
    num_patches  = d.get_attribute( ATTR_ID, ATTR_NUM_PATCHES )
    # Remove attributes
    TT::Model.start_operation( 'Convert to Mesh' )
    d.attribute_dictionaries.delete( ATTR_ID )
    for index in (0...num_patches)
      section = "BezierPatch#{index}"
      d.attribute_dictionaries.delete( section )
    end
    model.commit_operation
    # Clear the selection so there is some kind of user feedback of an event.
    model.selection.clear
    true
  end

end # module