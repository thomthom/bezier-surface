#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

#-------------------------------------------------------------------------------

module TT
 module Plugins
  module BezierSurfaceTools

  ### CONSTANTS ### ------------------------------------------------------------

  # Plugin information
  PLUGIN          = self
  PLUGIN_ID       = 'TT_BezierSurface'.freeze
  PLUGIN_NAME     = 'Bezier Surface'.freeze
  PLUGIN_VERSION  = '0.1.2'.freeze

  # Resource paths
  file = __FILE__.dup
  file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
  FILENAMESPACE = File.basename(file, '.*').freeze
  PATH_ROOT     = File.dirname(file).freeze
  PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze


  ### EXTENSION ### ------------------------------------------------------------

  unless file_loaded?(__FILE__)
    loader = File.join(PATH, 'core.rb')
    ex = SketchupExtension.new(PLUGIN_NAME, loader)
    ex.description = 'Bezier Surface modeling for SketchUp.'
    ex.version     = PLUGIN_VERSION
    ex.copyright   = 'Thomas Thomassen © 2010–2014'
    ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension(ex, true)
  end

  end # module BezierSurfaceTools
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
