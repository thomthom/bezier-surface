#-------------------------------------------------------------------------------
# Compatible: SketchUp 7 (PC)
#             (other versions untested)
#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.5.0', 'Bezier Surface')

#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  PLUGIN      = self
  ID          = 'TT_BezierSurface'.freeze
  VERSION     = '1.0.0'.freeze
  PLUGIN_NAME = 'Bezier Surface'.freeze
  
  ATTR_ID      = 'TT_Mesh'.freeze
  MESH_TYPE    = 'BezierSurface'.freeze
  MESH_VERSION = [1,0,0].freeze
  
  PATH = File.join( File.dirname( __FILE__ ), 'TT_BezierSurface' ).freeze
  PATH_ICONS = File.join( PATH, 'UI', 'Icons' ).freeze
  
  # UI Constants
  
  VERTEX_SIZE = 8
  
  MESH_GRID_LINE_WIDTH    = 2
  CTRL_GRID_LINE_WIDTH    = 3
  CTRL_GRID_BORDER_WIDTH  = 3
  
  CLR_VERTEX    = Sketchup::Color.new( 255,   0,   0 )
  CLR_MESH_GRID = Sketchup::Color.new( 128, 128, 128 )
  CLR_CTRL_GRID = Sketchup::Color.new( 255, 165,   0 )
  CLR_SELECTION = Sketchup::Color.new(  64,  64,  64 )
  
  CLR_PREVIEW_FILL    = Sketchup::Color.new( 128, 0, 255, 32 )
  CLR_PREVIEW_BORDER  = Sketchup::Color.new( 128, 0, 255 )
  
  
  ### MODULES ### --------------------------------------------------------------
  Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
    require( file )
  }
  
  
  ### VARIABLES ### ------------------------------------------------------------
  
  # Key is model.guid
  @editors = {}
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  # This method must be here as it needs to be availible when the script loads
  # so it can attach the model observer to the current model.
  def self.observe_model( model )
    model.add_observer( BP_ModelObserver.new )
    editor = BezierSurfaceEditor.new( model )
    @editors[model] = editor
    
    TT.debug( "Observe Model" )
    TT.debug( "> Instance Variable:" )
    e = model.instance_variable_set( :@tt_bezier_surface_editor, editor )
    TT.debug( "> #{e}" )
    
    nil
  end
  
  unless file_loaded?( File.basename(__FILE__) )
    # Commands
    cmd = UI::Command.new('Create Quadpatch') {
      self.draw_quadpatch
    }
    cmd.small_icon = File.join( PATH_ICONS, 'QuadPatch_16.png' )
    cmd.large_icon = File.join( PATH_ICONS, 'QuadPatch_24.png' )
    cmd.status_bar_text = 'Create a Quadpatch Bezier Surface'
    cmd.tooltip = 'Create a Quadpatch Bezier Surface'
    cmd_create_quad_patch = cmd
    
    # Menus
    m = TT.menu('Draw').add_submenu( PLUGIN_NAME )
    m.add_item( cmd_create_quad_patch )
    menu = m.add_item('Create Tripatch')    { puts 'Create Tripatch' }
    m.set_validation_proc(menu) { MF_DISABLED | MF_GRAYED }
    
    # Right click menu
    #UI.add_context_menu_handler { |context_menu|
      #model = Sketchup.active_model
      #sel = model.selection
      #if sel.length == 1 && BezierSurface.is?( sel[0] )
        #context_menu.add_item('refresh Bezier Surface') { 
        #  self.refresh_selected_surface
        #}
      #end
    #}
    
    # Toolbar
    toolbar = UI::Toolbar.new( PLUGIN_NAME )
    toolbar.add_item( cmd_create_quad_patch )
    if toolbar.get_last_state == TB_VISIBLE
      toolbar.restore
      UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
    end
    
    # Observers
    Sketchup.add_observer( BP_AppObserver.new )
    self.observe_model( Sketchup.active_model )
  end 
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------
  
  # Returns the BezierSurfaceEditor for the current model. This ensures the 
  # tool can be used for multiple models simultaneously - as is possible under
  # OSX.
  def self.get_editor( current_model )
    TT.debug( 'Editor' )
    TT.debug( "> #{current_model.inspect}" )
    TT.debug( "> #{current_model.guid}" )
    
    # Monitor if this work.
    TT.debug( "> Instance Variable:" )
    e = current_model.instance_variable_get( :@tt_bezier_surface_editor )
    TT.debug( "> #{e}" )
    TT.debug( (e) ? 'Editor Variable: OK' : 'Editor Variable: LOST!' )
    
    # (i) model.guid isn't always reliable - it can change so the model object
    # is also compared. Model is also not 100% reliable, which might be why
    # setting an instance variable doesn't seem to work. Combination of the
    # two appear to work - where one fails, the other works.
    #
    # This is far from an ideal thing to do and it's considered a hack until
    # a better reliable method is found.
    
    #@editors[current_model]
    @editors.each { |model, editor|
      return editor if model == current_model
      return editor if model.guid == model.guid
    }
    
    return nil
  end

  # Initates the tool to draw a new QuadPatch.
  def self.draw_quadpatch
    Sketchup.active_model.tools.push_tool( CreatePatchTool.new )
  end
  
  
  # Get Instructor Path
  #
  # Tool.getInstructorContentDirectory expects a path relative to SketchUp's
  # Resource/<locale>/helpcontent/ folder, despite the documentations use an
  # absolute path.
  #
  # This method is a wrapper that generates a path to the actual help content
  # which SketchUp can use.
  #
  # The given path must be under the same drive as SketchUp's help content.
  #
  # This quick exist in all current SketchUp versions.
  # Current: SketchUp 8 M1
  def self.get_instructor_path( path )
    path = File.expand_path( path )
    origin = Sketchup.get_resource_path( 'helpcontent' )
    # Check if drive matches
    origin_drive = origin.match( /^(\w):/ )
    if origin_drive
      origin_drive = origin_drive[1].downcase
    end
    path_drive = path.match( /^(\w):/ )
    if path_drive
      path_drive = path_drive[1].downcase
      path = path[2...path.size] # Trim drive letter
    end
    if path_drive && origin_drive
      return nil unless origin_drive == path_drive
    end
    # Build relative path
    parts = origin.split( File::SEPARATOR ).size
    path_to_root = "..#{File::SEPARATOR}" * parts
    relative_path = File.join( path_to_root, path )
    return relative_path
  end

  
  ### DEBUG ### ----------------------------------------------------------------
  
  # TT::Plugins::BezierSurfaceTools.reload
  def self.reload( tt_lib = false )
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
      load file
    }
    x.length
  end

end # module

#-------------------------------------------------------------------------------

file_loaded( File.basename(__FILE__) )

#-------------------------------------------------------------------------------