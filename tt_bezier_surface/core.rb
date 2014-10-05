#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.7.0', 'Bezier Surface')

#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools


  ### CONSTANTS ### ------------------------------------------------------------

  # Attribute dictionary keys
  ATTR_ID             = 'TT_Mesh'.freeze
  ATTR_TYPE           = 'Type'.freeze
  ATTR_VERSION        = 'Version'.freeze
  ATTR_SUBDIVS        = 'Subdivs'.freeze
  ATTR_POSITIONS      = 'Positions'.freeze
  ATTR_CONTROL_POINTS = 'ControlPoints'.freeze
  ATTR_VERTICES       = 'Vertices'.freeze
  ATTR_HANDLES        = 'Handles'.freeze
  ATTR_INTERIORPOINTS = 'InteriorPoints'.freeze
  ATTR_EDGES          = 'Edges'.freeze
  ATTR_EDGEUSES       = 'EdgeUses'.freeze
  ATTR_PATCHES        = 'Patches'.freeze
  ATTR_REVERSED       = 'Reversed'.freeze

  # Attribute dictionary values
  MESH_TYPE         = 'BezierSurface'.freeze
  MESH_NAME         = 'Bezier Surface'.freeze
  MESH_VERSION_R0   = TT::Version.new( 1,0,3 ).freeze
  MESH_VERSION_MIN  = MESH_VERSION_R0
  MESH_VERSION      = MESH_VERSION_R0

  # Subdivision range limit
  SUBDIVS_MIN     = 1
  SUBDIVS_MAX     = 48
  SUBDIVS_RANGE   = ( SUBDIVS_MIN..SUBDIVS_MAX ).freeze
  SUBDIVS_DEFAULT = 8
  SUBDIVS_PREVIEW = 4

  # Resource paths
  PATH_UI    = File.join( PATH, 'UI' ).freeze
  PATH_ICONS = File.join( PATH_UI, 'Icons' ).freeze

  # Inference
  LINEAR_SNAP_THRESHOLD = 6  # Pixels
  RADIAL_SNAP_THRESHOLD = 12 # Pixels
  INFERENCE_WIDTH = 1 # Pixels
  INFERENCE_STYLE = '.'

  # UI Constants
  VERTEX_SIZE = 8 # Pixels

  MESH_GRID_LINE_WIDTH    = 1 # Pixels
  CTRL_GRID_LINE_WIDTH    = 3 # Pixels
  CTRL_GRID_BORDER_WIDTH  = 3 # Pixels

  # Tool.cancel Reason Codes
  CANCEL_ESC        = 0
  CANCEL_REACTIVATE = 1
  CANCEL_UNDO       = 2

  # Colours
  CLR_VERTEX        = Sketchup::Color.new( 255,   0,   0 )
  CLR_HANDLE_POINT  = Sketchup::Color.new(   0, 128,   0 )
  CLR_HANDLE_ARM    = Sketchup::Color.new(   0, 192,   0 )
  CLR_INTERIOR      = Sketchup::Color.new(   0,   0,   0 )
  CLR_EDGE          = Sketchup::Color.new(  64,  64, 128 )
  CLR_EDGE_SELECTED = Sketchup::Color.new( 255, 165,   0 )
  CLR_PATCH         = Sketchup::Color.new(   0,   0, 255, 64 )

  CLR_MESH_GRID     = Sketchup::Color.new( 128, 128, 128 )
  CLR_CTRL_GRID     = Sketchup::Color.new( 255, 165,   0 )

  CLR_SELECTION     = Sketchup::Color.new(  64,  64,  64 )

  CLR_PREVIEW_FILL    = Sketchup::Color.new( 128, 0, 255, 32 )
  CLR_PREVIEW_BORDER  = Sketchup::Color.new( 128, 0, 255 )


  ### MODULES ### --------------------------------------------------------------
  # Ensure abstract classes are loaded and found when needed.
  autoload( :Observable,      File.join( PATH, 'observable.rb' ) )
  autoload( :BezierEntity,    File.join( PATH, 'bezier_entity.rb' ) )
  autoload( :BezierPatch,     File.join( PATH, 'bezier_patch.rb' ) )
  autoload( :Operator,        File.join( PATH, 'operator.rb' ) )
  autoload( :OperatorManager, File.join( PATH, 'operator_manager.rb' ) )
  # Load all ruby files.
  Dir.glob( File.join( PATH, '*.{rb,rbs}' ) ).each { |file|
    # (!) Strip extension and use Sketchup::require for production.
    require( file )
  }


  ### DEBUGGING ### ------------------------------------------------------------

  # TT::Plugins::BezierSurfaceTools::Console.output = true
  # TT::Plugins::BezierSurfaceTools::Console.external = true

  DEBUG = false
  Console = DebugConsole.new( DEBUG, true )


  ### VARIABLES ### ------------------------------------------------------------

  # Key is model.guid
  @editors ||= {}


  ### MENU & TOOLBARS ### ------------------------------------------------------

  # This method must be here as it needs to be availible when the script loads
  # so it can attach the model observer to the current model.
  #
  # @param [Sketchup::Model] model
  #
  # @return [Nil]
  # @since 1.0.0
  def self.observe_model( model )
    model.add_observer( BST_ModelObserver.new )
    editor = BezierSurfaceEditor.new( model )
    @editors[model] = editor

    Console.log( "Observe Model" )
    Console.log( "> Instance Variable:" )
    e = model.instance_variable_set( :@tt_bezier_surface_editor, editor )
    Console.log( "> #{e}" )

    nil
  end

  unless file_loaded?( File.basename(__FILE__) )
    # Menus
    m = TT.menu( 'Draw' ).add_submenu( PLUGIN_NAME )
    m.add_item( Commands.create_quad_patch )
    m.add_item( Commands.create_tri_patch )

    m = UI.menu( 'Window' )
    m.add_item( Commands.toggle_properties )

    # Context menu
    UI.add_context_menu_handler { |context_menu|
      model = Sketchup.active_model
      selection = model.selection
      if selection.length == 1 && BezierSurface.is?( selection[0] )
        menu = context_menu.add_submenu( PLUGIN_NAME )

        menu.add_item( Commands.clone )
        menu.add_item( Commands.select_clone )
        menu.add_item( Commands.replace_clone )

        menu.add_separator

        menu.add_item( Commands.extract_edges )
        menu.add_item( Commands.extract_control_grid )

        menu.add_separator

        menu.add_item( Commands.convert_to_mesh )
        menu.add_item( Commands.convert_to_quadmesh )

        menu.add_separator

        menu.add_item( Commands.update_selected )
        menu.add_item( Commands.toggle_properties )
      end
    }

    # Toolbar
    toolbar = UI::Toolbar.new( PLUGIN_NAME )
    toolbar.add_item( Commands.create_quad_patch )
    toolbar.add_item( Commands.create_tri_patch )
    if toolbar.get_last_state == TB_VISIBLE
      toolbar.restore
      UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
    end

    # Observers
    Sketchup.add_observer( BST_AppObserver.new )
    self.observe_model( Sketchup.active_model )
  end


  ### MAIN SCRIPT ### ----------------------------------------------------------

  # Returns the {BezierSurfaceEditor} for the current model. This ensures the
  # tool can be used for multiple models simultaneously - as is possible under
  # OSX.
  #
  # @param [Sketchup::Model] current_model
  #
  # @return [BezierSurfaceEditor,Nil]
  # @since 1.0.0
  def self.get_editor( current_model )
    Console.log( 'get_editor' )
    #Console.log( "  > #{current_model.inspect}" )
    #Console.log( "  > #{current_model.guid}" )

    # Monitor if this work.
    #Console.log( "  > Instance Variable:" )
    e = current_model.instance_variable_get( :@tt_bezier_surface_editor )
    Console.log( "> #{e}" )
    Console.log( (e) ? '> Editor Variable: OK' : '> Editor Variable: LOST!' )

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


  # Get Instructor Path
  #
  # +Tool.getInstructorContentDirectory+ expects a path relative to SketchUp's
  # +Resource/<locale>/helpcontent/+ folder, despite the documentations use an
  # absolute path.
  #
  # This method is a wrapper that generates a path to the actual help content
  # which SketchUp can use.
  #
  # The given path must be under the same drive as SketchUp's help content.
  #
  # This quick exist in all current SketchUp versions.
  #
  # Current SketchUp version: SketchUp 8 M1
  #
  # @param [String] path
  #
  # @return [String,Nil]
  # @since 1.0.0
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

  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::BezierSurfaceTools.reload
  #
  # @param [Boolean] tt_lib
  #
  # @return [Integer]
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
      load file
    }
    x.length
  ensure
    $VERBOSE = original_verbose
  end

end if Sketchup.version.to_i > 6

#-------------------------------------------------------------------------------

file_loaded( File.basename(__FILE__) )

#-------------------------------------------------------------------------------
