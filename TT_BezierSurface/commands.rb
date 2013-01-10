#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  module Commands
    
    # @return [UI::Command]
    # @since 1.0.0
    def self.create_quad_patch
      unless @create_quad_patch
        cmd = UI::Command.new( 'Create Quadpatch' ) {
          Operations.draw_quadpatch
        }
        cmd.small_icon = File.join( PATH_ICONS, 'QuadPatch_16.png' )
        cmd.large_icon = File.join( PATH_ICONS, 'QuadPatch_24.png' )
        cmd.status_bar_text = 'Create a Quadpatch Bezier Surface.'
        cmd.tooltip = 'Create a Quadpatch Bezier Surface'
        @create_quad_patch = cmd
      end
      @create_quad_patch
    end
    
    # @return [UI::Command]
    # @since 1.0.0
    def self.create_tri_patch
      unless @create_tri_patch
        cmd = UI::Command.new( 'Create Tripatch' ) {
          UI.messagebox( 'Not implemented' )
        }
        cmd.small_icon = File.join( PATH_ICONS, 'TriPatch_16.png' )
        cmd.large_icon = File.join( PATH_ICONS, 'TriPatch_24.png' )
        cmd.status_bar_text = 'Create a Tripatch Bezier Surface.'
        cmd.tooltip = 'Create a Tripatch Bezier Surface'
        cmd.set_validation_proc { MF_GRAYED }
        @create_tri_patch = cmd
      end
      @create_tri_patch
    end
    
    # @return [UI::Command]
    # @since 1.0.0
    def self.convert_to_mesh
      unless @convert_to_mesh
        cmd = UI::Command.new( 'Convert to Editable Mesh' ) {
          Operations.convert_selected_to_mesh
        }
        cmd.status_bar_text = 'Convert selected Surface to editable mesh.'
        cmd.tooltip = 'Convert selected Surface to editable mesh'
        @convert_to_mesh = cmd
      end
      @convert_to_mesh
    end

    # @return [UI::Command]
    # @since 1.0.0
    def self.convert_to_quadmesh
      unless @convert_to_quadmesh
        cmd = UI::Command.new( 'Convert to Editable Quadmesh' ) {
          Operations.convert_selected_to_quadmesh
        }
        cmd.status_bar_text = 'Convert selected Surface to editable quadmesh.'
        cmd.tooltip = 'Convert selected Surface to editable quadmesh'
        @convert_to_quadmesh = cmd
      end
      @convert_to_quadmesh
    end
    
    # @return [UI::Command]
    # @since 1.0.0
    def self.clone
      unless @clone
        cmd = UI::Command.new( 'Clone' ) {
          UI.messagebox( 'Not implemented' )
        }
        cmd.status_bar_text = 'Clone selected Surface.'
        cmd.tooltip = 'Clone selected Surface'
        cmd.set_validation_proc { MF_GRAYED }
        @clone = cmd
      end
      @clone
    end
    
    # @return [UI::Command]
    # @since 1.0.0
    def self.replace_clone
      unless @replace_clone
        cmd = UI::Command.new( 'Replace Clone' ) {
          UI.messagebox( 'Not implemented' )
        }
        cmd.status_bar_text = 'Select all clones.'
        cmd.tooltip = 'Select all clones'
        cmd.set_validation_proc { MF_GRAYED }
        @replace_clone = cmd
      end
      @replace_clone
    end
    
    # @return [UI::Command]
    # @since 1.0.0
    def self.select_clone
      unless @select_clone
        cmd = UI::Command.new( 'Select Clone' ) {
          UI.messagebox( 'Not implemented' )
        }
        cmd.status_bar_text = 'Select all clones.'
        cmd.tooltip = 'Select all clones'
        cmd.set_validation_proc { MF_GRAYED }
        @select_clone = cmd
      end
      @select_clone
    end
    
    # @return [UI::Command]
    # @since 1.0.0
    def self.toggle_properties
      unless @toggle_properties
        cmd = UI::Command.new( 'Entity Properties' ) {
          PLUGIN::PropertiesWindow.toggle
        }
        cmd.status_bar_text = 'Show or Hide the Properties Window.'
        cmd.tooltip = 'Show or Hide the Properties Window'
        @toggle_properties = cmd
      end
      @toggle_properties
    end
    
    # @return [UI::Command]
    # @since 1.0.0
    def self.update_selected
      unless @update_selected
        cmd = UI::Command.new( 'Update' ) {
          Operations.update_selected_surface
        }
        cmd.status_bar_text = 'Updates selected Surface.'
        cmd.tooltip = 'Updates selected Surface'
        @update_selected = cmd
      end
      @update_selected
    end
    
    # @return [UI::Command]
    # @since 1.0.0
    def self.extract_edges
      unless @extract_edges
        cmd = UI::Command.new( 'Extract Edges' ) {
          UI.messagebox( 'Not implemented' )
        }
        cmd.status_bar_text = 'Extracts Bezier Edges into a group of Bezier Curves.'
        cmd.tooltip = 'Extracts Bezier Edges'
        cmd.set_validation_proc { MF_GRAYED }
        @extract_edges = cmd
      end
      @extract_edges
    end
    
     # @return [UI::Command]
    # @since 1.0.0
    def self.extract_control_grid
      unless @extract_control_grid
        cmd = UI::Command.new( 'Extract Control Grid' ) {
          UI.messagebox( 'Not implemented' )
        }
        cmd.status_bar_text = 'Extracts the control grid into a group.'
        cmd.tooltip = 'Extracts Control Grid'
        cmd.set_validation_proc { MF_GRAYED }
        @extract_control_grid = cmd
      end
      @extract_control_grid
    end
  
  end # module Commands

end # module