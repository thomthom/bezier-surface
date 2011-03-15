module TT::Plugins::BezierSurfaceTools

  
  # Detect new models and attach a model observer to monitor when the user
  # opens a Bezier Surface for editing.
  class BP_AppObserver < Sketchup::AppObserver
  
    def onNewModel(model)
      #TT.debug( 'BP_onNewModel' )
      PLUGIN.observe_model( model )
    end
    
    def onOpenModel(model)
      #TT.debug( 'BP_onOpenModel' )
      PLUGIN.observe_model( model )
    end

  end # class BP_AppObserver
  
  
  # When the user opens a Group/ComponentInstance containing a Bezier Surface
  # for editing - activate the Bezier editing tools.
  #
  # When the user closes a Bezier Surface Group/ComponentInstance the
  # edit session is ended. 
  class BP_ModelObserver < Sketchup::ModelObserver
  
    def onActivePathChanged(model)
      # (!) This appear to trigger on occations when not expected. Errors can
      # appear reporting reference to missing entity. The model? Or maybe
      # the instance - get_attribute might have been a trigger point...
      
      #TT.debug( 'BP_onActivePathChanged' )
      instance = (model.active_path.nil?) ? nil : model.active_path.last
      if TT::Instance.is?( instance ) && BezierSurface.is?( instance )
        #TT.debug( '> New Session...' )
        #BezierSurfaceEditor.new( instance ) # ???
        editor = PLUGIN.get_editor( model )
        editor.edit( instance )
        #model.selection.clear
      else
        #TT.debug( '> Ending Session...' )
        editor = PLUGIN.get_editor( model )
        #TT.debug( editor )
        editor.end_session unless editor.nil?
      end
    end
    
    #
    
  end # class BP_ModelObserver
  
  
  # Detect when a user undo an editing operation while editing a Bezier Surface.
  #
  # (!) Probably merge this with the main observer - the undo/redo events are
  # needed to detect when undo/redo changes the current context as it does not
  # trigger onActivePathChanged.
  class BP_Editor_ModelObserver < Sketchup::ModelObserver
  
    def onTransactionUndo(model)
      #TT.debug( 'BP_Editor_ModelObserver.onTransactionUndo' )
      editor = PLUGIN.get_editor( model )
      editor.undo_redo
    end
    
    def onTransactionRedo(model)
      #TT.debug( 'BP_Editor_ModelObserver.onTransactionRedo' )
      editor = PLUGIN.get_editor( model )
      editor.undo_redo
    end
    
  end # class BP_ModelObserver

  
end # TT::Plugins::BezierSurfaceTools