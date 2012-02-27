#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools

  
  # Detect new models and attach a model observer to monitor when the user
  # opens a Bezier Surface for editing.
  #
  # @since 1.0.0
  class BST_AppObserver < Sketchup::AppObserver
    
    # @param [Sketchup::Model] model
    # @since 1.0.0
    def onNewModel( model )
      PLUGIN.observe_model( model )
    end
    
    # @param [Sketchup::Model] model
    # @since 1.0.0
    def onOpenModel( model )
      PLUGIN.observe_model( model )
    end

  end # class BST_AppObserver
  
  
  # When the user opens a Group/ComponentInstance containing a Bezier Surface
  # for editing - activate the Bezier editing tools.
  #
  # When the user closes a Bezier Surface Group/ComponentInstance the editing
  # session is ended.
  #
  # @since 1.0.0
  class BST_ModelObserver < Sketchup::ModelObserver
    
    # @param [Sketchup::Model] model
    # @since 1.0.0
    def onActivePathChanged( model )
      # (!) This appear to trigger on occations when not expected. Errors can
      # appear reporting reference to missing entity. The model? Or maybe
      # the instance - get_attribute might have been a trigger point...
      #
      # 2011-03-22
      # Not noticed this again. Maybe the issue is gone. Or it was an observer
      # reload issue.
      
      #Console.log( 'BST_ModelObserver.onActivePathChanged' )
      check_active_path( model )
    end
    
    # @param [Sketchup::Model] model
    # @since 1.0.0
    def onTransactionUndo( model )
      Console.log( 'BST_ModelObserver.onTransactionUndo' )
      check_active_path( model, true )
    end
    
    # @param [Sketchup::Model] model
    # @since 1.0.0
    def onTransactionRedo( model )
      Console.log( 'BST_ModelObserver.onTransactionRedo' )
      check_active_path( model, true )
    end
    
    # If it's a valid bezier surface context, ensure that an editor is
    # active. This must be checked in the undo events because 
    # onActivePathChanged does not trigger when undo/redo cause the
    # active context to change.
    #
    # @param [Sketchup::Model] model
    # @param [Boolean] undo_redo Indicate an undo/redo event triggered the check.
    #
    # @since 1.0.0
    def check_active_path( model, undo_redo = false )
      Console.log( 'BST_ModelObserver.check_active_path' )
      instance = (model.active_path) ? model.active_path.last : nil
      editor = PLUGIN.get_editor( model )
      if TT::Instance.is?( instance ) && BezierSurface.is?( instance )
        Console.log( '> Is BezierSurface' )
        if editor
          # Valid context, ensure an editor is active.
          unless editor.active?
            Console.log( '  > Activating editor...' )
            editor.edit( instance )
            editor.undo_redo if undo_redo
          else
            Console.log( '  > Editor already active.' )
            editor.undo_redo if undo_redo
          end
        else
          Console.log( '  > No Editor!' )
          # (?) Error? State not seen.
        end
      else
        Console.log( '> Is Not BezierSurface' )
        editor.end_session # Ensures any active sessions is ended.
      end
      nil
    end
    
  end # class BST_ModelObserver
  
  
  # Monitors the model selection for changes. The selection can be
  # Sketchup::Selection or {Selection}.
  #
  # @todo Monitor both native and custom selection.
  #       Notify Entity Properties window of changes.
  #
  # @since 1.0.0
  class BST_SelectionObserver < Sketchup::SelectionObserver
    
    # @param [Sketchup::Selection] selection
    # @since 1.0.0
    def onSelectionBulkChange( selection )
      #Console.log 'BST_SelectionObserver.onSelectionBulkChange'
      editor = PLUGIN.get_editor( selection.model )
      if editor
        editor.refresh_viewport
      end
    end
    
    # @param [Sketchup::Selection] selection
    # @since 1.0.0
    def onSelectionCleared( selection )
      #Console.log 'BST_SelectionObserver.onSelectionCleared'
      editor = PLUGIN.get_editor( selection.model )
      if editor
        editor.refresh_viewport
      end
    end
    
    # @return [BST_SelectionObserver]
    # @since 1.0.0
    def self.factory
      @@observer ||= self.new
      @@observer
    end
    
  end # class BST_SelectionObserver
  
  
  # Monitors a surface for changes - ensuring things are kept up to date.
  #
  # @since 1.0.0
  class BST_SurfaceObserver
    
    # @param [BezierSurface] surface
    # @since 1.0.0
    def onContentModified( surface )
      #Console.log 'BST_SurfaceObserver.onContentModified'
      editor = PLUGIN.get_editor( surface.model )
      if editor
        # Check for erased entites.
        erased = editor.selection.select { |entity| entity.deleted? }
        editor.selection.remove( erased )
        # Update the viewport
        # The Selection modification will trigger the viewport refresh.
        editor.refresh_viewport if erased.empty?
      end
    end
    
    # @return [BST_SurfaceObserver]
    # @since 1.0.0
    def self.factory
      @@observer ||= self.new
      @@observer
    end
    
  end # class BST_SurfaceObserver

  
end # TT::Plugins::BezierSurfaceTools