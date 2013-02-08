#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::BezierSurfaceTools
  
  # @since 1.0.0
  class EntityCache

    attr_reader :editor

    # @param [Editor] editor
    # @param [Array<BezierEntity>] entities Currently just control points.
    #
    # @since 1.0.0
    def initialize( editor, entities )
      @editor = editor
      @cache = {}
      for point in entities
        @cache[ point ] = point.position.clone
      end
    end

    # @param [Geom::Transformation] transformation
    # @param [Boolean] preview
    #
    # @since 1.0.0
    def transform_entities( transformation, preview = false )
      entities = []
      vectors = []
      for control_point, original_position in @cache
        if transformation.identity? # (!) Not reliable
          new_point = original_position
        else
          new_point = original_position.transform( transformation )
        end
        vector = control_point.position.vector_to( new_point )
        next unless vector.valid?
        entities << control_point
        vectors << vector
      end
      unless entities.empty?
        @editor.surface.transform_by_vectors( entities, vectors )
      end
      if preview
        @editor.surface.preview
      else
        @editor.surface.update
      end
      !entities.empty?
    end

    # @since 1.0.0
    def inspect
      id = TT.object_id_hex( self )
      "#<#{self.class.name}:#{id} - #{@cache.length} entities>"
    end

  end # class

end # module