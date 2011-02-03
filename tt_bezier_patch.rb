#-----------------------------------------------------------------------------
# Compatible: SketchUp 7 (PC)
#             (other versions untested)
#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

# Create Tool
# Edit Tool
# Extrude Tool
# Merge/Join Tool
# Modifiers (Noise,Shell)

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.5.0', 'Bezier Surface')

#require 'TT_BezierPatch/bezier_surface_editor.rb'
#require 'TT_BezierPatch/tool_create_patch.rb'
#require 'TT_BezierPatch/tool_edit_patch.rb'
#require 'TT_BezierPatch/bezier_patch.rb'
#require 'TT_BezierPatch/bezier_surface.rb'
#require 'TT_BezierPatch/quad_patch.rb'
#require 'TT_BezierPatch/observers.rb'


#-----------------------------------------------------------------------------


module TT::Plugins::BPatch
  
  
  ### CONSTANTS ### --------------------------------------------------------
  
  ID        = 'TT_BezierSurface'.freeze
  VERSION   = '1.0.0'.freeze
  
  ATTR_ID   = 'TT_Mesh'.freeze
  MESH_TYPE = 'BezierSurface'.freeze
  
  PATH = File.join( File.dirname( __FILE__ ), 'TT_BezierPatch' ).freeze
  
  # UI Constants
  
  VERTEX_SIZE = 8
  
  MESH_GRID_LINE_WIDTH    = 2
  CTRL_GRID_LINE_WIDTH    = 3
  CTRL_GRID_BORDER_WIDTH  = 3
  
  CLR_VERTEX    = Sketchup::Color.new( 255,   0,   0 )
  CLR_MESH_GRID = Sketchup::Color.new( 128, 128, 128 )
  CLR_CTRL_GRID = Sketchup::Color.new( 255, 165,   0 )
  CLR_SELECTION = Sketchup::Color.new(  64,  64,  64 )
  
  
  ### MODULES ### ----------------------------------------------------------
  Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
    require( file )
  }
  
  
  ### VARIABLES ### --------------------------------------------------------
  
  # Key is model.guid
  @editors = {}
  
  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  # This method must be here as it needs to be availible when the script loads
  # so it can attach the model observer to the current model.
  def self.observe_model( model )
    model.add_observer( BP_ModelObserver.new )
    @editors[model] = BezierSurfaceEditor.new( model )
    
    #editor = BezierSurfaceEditor.new( model )
    #model.instance_variable_set(:@tt_bezier_surface_editor, editor)
  end
  
  unless file_loaded?( File.basename(__FILE__) )
    m = TT.menu('Draw').add_submenu('Bezier Surface')
    m.add_item('Create Quadpatch')   { self.draw_quadpatch }
    menu = m.add_item('Create Tripatch')    { self.draw_quadpatch }
    m.set_validation_proc(menu) { MF_DISABLED | MF_GRAYED }

    #m.add_separator
    #m.add_item('Edit Surface')      { self.edit_surface }
    
    # Right click menu
    #UI.add_context_menu_handler { |context_menu|
      #model = Sketchup.active_model
      #sel = model.selection
      #if sel.length == 1 && BezierSurface.is?( sel[0] )
        #context_menu.add_item('Edit Bezier Surface') { 
        #  self.edit_surface
        #}
      #end
    #}
    
    # Observers
    Sketchup.add_observer( BP_AppObserver.new )
    self.observe_model( Sketchup.active_model )
  end 
  
  
  ### MAIN SCRIPT ### ------------------------------------------------------
  
  # Returns the BezierSurfaceEditor for the current model. This ensures the 
  # tool can be used for multiple models simultaniously - as is possible under
  # OSX.
  def self.editor( model )
    TT.debug( 'Editor' )
    #TT.debug( "> #{model.inspect}" )
    #TT.debug( "> #{model.guid}" )
    #@editors[model]
    
    @editors.each { |m,e|
      return e if m == model
      return e if m.guid == model.guid
    }
    
    #model.instance_variable_get(:@tt_bezier_surface_editor)
  end

  # Initates the tool to draw a new QuadPatch.
  def self.draw_quadpatch
    Sketchup.active_model.tools.push_tool( CreatePatchTool.new )
  end

  
  ### DEBUG ### ------------------------------------------------------------
  
  def self.reload
    TT::Lib.reload
    # Core file (this)
    load __FILE__
    # Supporting files
    x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
      load file
    }
    x.length
  end

end # module

#-----------------------------------------------------------------------------

file_loaded( File.basename(__FILE__) )

#-----------------------------------------------------------------------------