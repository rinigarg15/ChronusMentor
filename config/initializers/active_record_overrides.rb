module ActiveRecord
  module ConnectionAdapters
    class AbstractMysqlAdapter < AbstractAdapter
      # Without this change: where("foo_at >= ?", 1.day.ago) => foo_at >= '2015-11-02 04:48:18.934162'
      # With this change:  where("foo_at >= ?", 1.day.ago) => foo_at >= '2015-11-02 04:48:18'
      def supports_datetime_with_precision?
        false
      end
    end
  end
end

module ActiveRecordRelationWithEsDeltaIndexing
  ################################################################################################################
  # By default update_all/update_columns or delete_all/delete won't trigger after_save or after_destroy callbacks.
  # With the below patch elasticsearch delta indexing will happen in update_all/delete_all actions.
  # Inorder to skip elasticsearch delta indexing in update_all/delete_all, pass the option :skip_delta_indexing as true.
  # For example:
  # User.where(state: 'dormant').update_all(state: 'suspended', skip_delta_indexing: true)
  # User.find_by(id: 1).update_columns(state: 'suspended', skip_delta_indexing: true)
  # User.where(state: 'dormant').delete_all(skip_delta_indexing: true)
  #
  # GOTCHAS !!!
  # skip_delta_indexing option can't be passed for arel's update_column and delete actions.
  #
  #################################################################################################################

  def update_all(updates)
    skip_delta_indexing = updates.delete(:skip_delta_indexing) if updates.is_a?(Hash)
    skip_delta_indexing ||= (ChronusElasticsearch.skip_es_index || DelayedEsDocument.instance_variable_get("@skip_es_delta_indexing"))
    objects = self.load unless skip_delta_indexing
    result = super(updates)
    return result if skip_delta_indexing
    return result if updates.is_a?(Hash) && updates.keys == ["updated_at"] && @klass.const_defined?("REINDEX_FOR_UPDATED_AT").blank?
    DelayedEsDocument.arel_delta_indexer(@klass, objects, :update)
    result
  end

  def delete_all(options = {})
    # arel will be cleared post record deletion so copying it temporarily for post process.
    skip_delta_indexing = options[:skip_delta_indexing]
    skip_delta_indexing ||= (ChronusElasticsearch.skip_es_index || DelayedEsDocument.instance_variable_get("@skip_es_delta_indexing"))
    objects = self.load.dup.to_a unless skip_delta_indexing
    result = super()
    return result if skip_delta_indexing
    DelayedEsDocument.arel_delta_indexer(@klass, objects, :delete)
    result
  end
end

module ActiveRecordConnectionAdaptersTableDefinitionAddSourceAuditKey
  def timestamps(**options)
    # Maximum limit to index a UTF8_MB4 column is 191.
    # 'source_audit_key' column is used for tracking rows migrated from a different database.
    ############## overridden code ####################
    column(SOURCE_AUDIT_KEY.to_sym, :string, { limit: UTF8MB4_VARCHAR_LIMIT } )
    ############## overridden code ####################
    super
  end
end

module ActiveRecordAttributeMethodsRemoveSourceAuditKey
  # 'source_audit_key' column is used for tracking rows migrated from a different database.
  def attributes
    super.except(SOURCE_AUDIT_KEY)
  end
end

module ActiveRecordConnectionAdaptersSchemaCacheRemoveSourceAuditKey
  def columns(table_name)
    super.reject { |column| column.name == SOURCE_AUDIT_KEY }
  end
end

ActiveRecord::Relation.prepend(ActiveRecordRelationWithEsDeltaIndexing)
ActiveRecord::ConnectionAdapters::TableDefinition.prepend(ActiveRecordConnectionAdaptersTableDefinitionAddSourceAuditKey)
ActiveRecord::Base.prepend(ActiveRecordAttributeMethodsRemoveSourceAuditKey)
ActiveRecord::ConnectionAdapters::SchemaCache.prepend(ActiveRecordConnectionAdaptersSchemaCacheRemoveSourceAuditKey)