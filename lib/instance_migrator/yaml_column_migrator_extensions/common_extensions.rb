module InstanceMigrator
  module YamlColumnMigratorExtensions
    module CommonExtensions

      def get_ids_with_source_audit_key(model, source_audit_key, options = {})
        ar_relation = get_ar_relation_for_source_audit_key(model, source_audit_key, options)
        if options[:order].present?
          ar_relation = ar_relation.order(options[:order])
        end
        ar_relation.collect(&:id)
      end

      def get_ar_relation_for_source_audit_key(model, source_audit_key, options = {})
        model.where("source_audit_key #{options[:match_condition]} #{source_audit_key}")
      end

      def get_source_audit_key(id)
        "'#{source_environment}_#{source_seed}_#{id}'"
      end

      def get_role_ids(roles)
        return if roles.blank?
        source_audit_keys = roles.collect{|role| get_source_audit_key(role)}.join(",")
        order_condition = "FIELD(source_audit_key, #{source_audit_keys})"
        get_ids_with_source_audit_key(Role, "(#{source_audit_keys})", {match_condition: "IN", order: order_condition})
      end

      def get_new_choice_ids(choice_ids, ref_obj_type, separator = COMMA_SEPARATOR)
        return "" if choice_ids.blank?
        source_audit_keys = choice_ids.split(separator).map(&:strip).collect{|choice| get_source_audit_key(choice)}.join(separator)
        order_condition = "FIELD(source_audit_key, #{source_audit_keys})"
        query = QuestionChoice.where(ref_obj_type: ref_obj_type)
        new_ids = get_ids_with_source_audit_key(query, "(#{source_audit_keys})", {match_condition: "IN", order: order_condition})
        new_ids.join(separator)
      end

      def get_new_id(old_id, model)
        source_audit_key = get_source_audit_key(old_id)
        get_ids_with_source_audit_key(model, source_audit_key, {match_condition: "="}).first
      end

      def get_bulk_source_audit_keys(old_ids)
        old_ids.collect {|old_id| get_source_audit_key(old_id)}.join(",")
      end
    end
  end
end