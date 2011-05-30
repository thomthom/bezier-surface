#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

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
    edges = editor.selection.edges
    edges.reject! { |edge| edge.patches.size > 1 }
    return false if edges.empty?
    model.start_operation( 'Add Quad Patch', true )
    for edge in edges
      edge.extrude_quad_patch
    end
    editor.surface.update
    model.commit_operation
    editor.refresh_ui
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
    return false if model.selection.length < 1
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
    # Remove attributes
    TT::Model.start_operation( 'Convert to Mesh' )
    if d.attribute_dictionaries
      d.attribute_dictionaries.delete( ATTR_ID )
    end
    model.commit_operation
    # Clear the selection so there is some kind of user feedback of an event.
    model.selection.clear
    true
  end
  
  
  # @return [Boolean]
  # @since 1.0.0
  def self.update_selected_surface
    # Verify selection.
    model = Sketchup.active_model
    return false if model.selection.length < 1
    instance = model.selection[0]
    return false unless BezierSurface.is?( instance )
    surface = BezierSurface.load( instance )
    return false unless surface
    TT::Model.start_operation( 'Update Surface' )
    surface.update
    model.commit_operation
    true
  end

end # module