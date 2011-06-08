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
  
    # @since 1.0.0
    def onNewModel(model)
      #TT.debug( 'BST_AppObserver.onNewModel' )
      PLUGIN.observe_model( model )
    end
    
    # @since 1.0.0
    def onOpenModel(model)
      #TT.debug( 'BST_AppObserver.onOpenModel' )
      PLUGIN.observe_model( model )
    end

  end # class BST_AppObserver
  
  
  # When the user opens a Group/ComponentInstance containing a Bezier Surface
  # for editing - activate the Bezier editing tools.
  #
  # When the user closes a Bezier Surface Group/ComponentInstance the
  # edit session is ended.
  #
  # @since 1.0.0
  class BST_ModelObserver < Sketchup::ModelObserver
  
    # @since 1.0.0
    def onActivePathChanged( model )
      # (!) This appear to trigger on occations when not expected. Errors can
      # appear reporting reference to missing entity. The model? Or maybe
      # the instance - get_attribute might have been a trigger point...
      #
      # 2011-03-22
      # Not noticed this again. Maybe the issue is gone. Or it was an observer
      # reload issue.
      
      #TT.debug( 'BST_ModelObserver.onActivePathChanged' )
      check_active_path( model )
    end
    
    # @since 1.0.0
    def onTransactionUndo( model )
      TT.debug( 'BST_ModelObserver.onTransactionUndo' )
      check_active_path( model, true )
    end
    
    # @since 1.0.0
    def onTransactionRedo( model )
      TT.debug( 'BST_ModelObserver.onTransactionRedo' )
      check_active_path( model, true )
    end
    
    # If it's a valid bezier surface context, ensure that an editor is
    # active. This must be checked in the undo events because 
    # onActivePathChanged does not trigger when undo/redo cause the
    # active context to change.
    #
    # @since 1.0.0
    def check_active_path( model, undo_redo = false )
      TT.debug( 'BST_ModelObserver.check_active_path' )
      instance = (model.active_path) ? model.active_path.last : nil
      editor = PLUGIN.get_editor( model )
      if TT::Instance.is?( instance ) && BezierSurface.is?( instance )
        TT.debug( '> Is BezierSurface' )
        if editor
          # Valid context, ensure an editor is active.
          unless editor.active?
            TT.debug( '  > Activating editor...' )
            editor.edit( instance )
            editor.undo_redo if undo_redo
          else
            TT.debug( '  > Editor already active.' )
            editor.undo_redo if undo_redo
          end
        else
          TT.debug( '  > No Editor!' )
          # (?) Error? State not seen.
        end
      else
        TT.debug( '> Is Not BezierSurface' )
        editor.end_session # Ensures any active sessions is ended.
      end
      nil
    end
    
  end # class BST_ModelObserver
  
  
  # @since 1.0.0
  class BST_SelectionObserver < Sketchup::SelectionObserver
    
    # @since 1.0.0
    def onSelectionBulkChange( selection )
      #puts 'BST_SelectionObserver.onSelectionBulkChange'
      editor = PLUGIN.get_editor( selection.model )
      if editor
        editor.refresh_viewport
      end
    end
    
    # @since 1.0.0
    def onSelectionCleared( selection )
      #puts 'BST_SelectionObserver.onSelectionCleared'
      editor = PLUGIN.get_editor( selection.model )
      if editor
        editor.refresh_viewport
      end
    end
    
    # @since 1.0.0
    def self.factory
      @@observer ||= self.new
      @@observer
    end
    
  end # class BST_SelectionObserver
  
  
  # @since 1.0.0
  class BST_SurfaceObserver
    
    # @since 1.0.0
    def onContentModified( surface )
      #puts 'BST_SurfaceObserver.onContentModified'
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
    
    # @since 1.0.0
    def self.factory
      @@observer ||= self.new
      @@observer
    end
    
  end # class BST_SurfaceObserver

  
end # TT::Plugins::BezierSurfaceTools