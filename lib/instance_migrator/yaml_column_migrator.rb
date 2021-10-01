module InstanceMigrator
  class YamlColumnMigrator
    include YamlColumnMigratorExtensions::CommonExtensions
    include YamlColumnMigratorExtensions::AdminViewExtensions

    attr_accessor :source_environment, :source_seed

    ANCESTRY_ASSOCIATED_MODELS = {"Post" => "ancestry"}

    def initialize(source_environment, source_seed)
      self.source_seed = source_seed
      self.source_environment = source_environment
    end

    def migrate_yaml_columns
      DelayedEsDocument.skip_es_delta_indexing do
        migrate_response_id_for_survey_answer
        migrate_mentoring_model_task_and_template(MentoringModel::Task)
        migrate_mentoring_model_task_and_template(MentoringModel::TaskTemplate)
        migrate_user_state_change
        migrate_user_csv_import
        migrate_admin_view
        migrate_campaigns
        migrate_ancestry_models
        migrate_chronus_versions
        migrate_admin_view_user_caches
        migrate_connection_memberships
        migrate_survey_questions
      end
    end

    private

    def migrate_response_id_for_survey_answer
      max_id = SurveyAnswer.unscoped.maximum(:response_id)
      query = "UPDATE common_answers SET response_id = response_id + 1000 + #{max_id} WHERE type= 'SurveyAnswer' AND source_audit_key LIKE #{get_source_audit_key('%')}"
      ActiveRecord::Base.connection.execute(query)
    end

    def migrate_admin_view_user_caches
      get_ar_relation_for_source_audit_key(AdminViewUserCache, get_source_audit_key("%"), {match_condition: "LIKE"}).where.not(user_ids: [nil, ""]).select(:id, :user_ids).each do |av_cache|
        update_admin_view_user_cache_user_ids(av_cache)
      end
    end

    def update_admin_view_user_cache_user_ids(admin_view_cache)
      old_user_ids = admin_view_cache.get_admin_view_user_ids
      return unless old_user_ids.present?
      new_ids = get_ids_with_source_audit_key(User, "(#{get_bulk_source_audit_keys(old_user_ids)})", {match_condition: "IN"})
      return unless new_ids.present?
      admin_view_cache.update_column(:user_ids, new_ids.join(COMMA_SEPARATOR))
    end

    def migrate_connection_memberships
      get_ar_relation_for_source_audit_key(Connection::Membership, get_source_audit_key("%"), {match_condition: "LIKE"}).where.not(last_applied_task_filter: [nil, ""]).select(:id, :last_applied_task_filter).each do |cm|
        update_last_applied_task_filter(cm)
      end
    end

    def update_last_applied_task_filter(connection_membership)
      return if connection_membership.user_info.blank? || connection_membership.user_info.to_i.zero?
      new_user_id = get_new_id(connection_membership.user_info.to_i, User)
      return unless new_user_id.present?
      new_last_applied_task_filter = connection_membership.last_applied_task_filter.merge({user_info: new_user_id.to_s})
      connection_membership.update_column(:last_applied_task_filter, new_last_applied_task_filter)
    end

    def migrate_survey_questions
      get_ar_relation_for_source_audit_key(SurveyQuestion, get_source_audit_key("%"), {match_condition: "LIKE"}).where("positive_outcome_options_management_report IS NOT NULL OR positive_outcome_options IS NOT NULL").select(:id, :positive_outcome_options, :positive_outcome_options_management_report).each do |sq|
        update_positive_outcome_options(sq, :positive_outcome_options)
        update_positive_outcome_options(sq, :positive_outcome_options_management_report)
      end
    end

    def update_positive_outcome_options(survey_question, column_name)
      old_choice_ids = survey_question.send(column_name)
      return unless old_choice_ids.present?
      new_choice_ids = get_new_choice_ids(old_choice_ids, "CommonQuestion", QuestionChoiceExtensions::SEPERATOR)
      return unless new_choice_ids.present?
      survey_question.update_column(column_name.to_sym, new_choice_ids)
    end

    def migrate_mentoring_model_task_and_template(model_name)
      get_ar_relation_for_source_audit_key(model_name, get_source_audit_key("%"), {match_condition: "LIKE"}).where.not(action_item_id: nil).select(:id, :action_item_id, :action_item_type).each do |object|
        klass = MentoringModel::TaskTemplate::ActionItem.action_item_name(object.action_item_type)
        next if klass.nil?
        new_id = get_new_id(object.action_item_id, klass)
        object.update_column(:action_item_id, new_id)
      end
    end

    def migrate_user_state_change
      get_ar_relation_for_source_audit_key(UserStateChange, get_source_audit_key("%"), {match_condition: "LIKE"}).where.not(info: nil).select(:id, :info, :connection_membership_info).each do |usc|
        column_values = {info: {value: usc.info_hash(true), role_keys: [:from, :to]}, connection_membership_info: {value: usc.connection_membership_info_hash(true), role_keys: [:from_role, :to_role]} }
        column_values.each do |key, value|
          yaml_info = value[:value]
          yaml_info = handle_role_keys_in_user_state_changes(value[:role_keys], yaml_info)
          usc.update_column(key.to_sym, yaml_info.to_yaml)
        end
      end
    end

    def handle_role_keys_in_user_state_changes(role_keys, yaml_info)
      roles = yaml_info[:role]
      role_keys.each do |role_key|
        ids = get_role_ids(roles[role_key])
        yaml_info[:role][role_key] = ids
      end
      yaml_info
    end

    def migrate_user_csv_import
      get_ar_relation_for_source_audit_key(UserCsvImport, get_source_audit_key("%"), {match_condition: "LIKE"}).where("info LIKE '%profile_question_%'").select(:id, :info).each do |uci|
        yaml_info = uci.info_hash
        ["profile_dropdown_choices", "processed_params", "processed_csv_import_params"].each do |major_key|
          (yaml_info[major_key] || {}).each do |key, value|
            update_key_in_user_csv_import_info!(yaml_info, major_key, key, value)
          end
        end
        uci.update_column(:info, yaml_info.to_yaml)
      end
    end

    def update_key_in_user_csv_import_info!(yaml_info, major_key, key, value)
      return unless value.match(/profile_question_/).present?
      yaml_info[major_key][key] = "profile_question_#{get_new_id(value.gsub("profile_question_", ""), ProfileQuestion).to_i}"
    end

    def migrate_chronus_versions
      get_ar_relation_for_source_audit_key(ChronusVersion, get_source_audit_key("%"), {match_condition: "LIKE"}).select(:id, :item_type, :object_changes).each do |version|
        belongs_to_associations = version.item_type.constantize.reflect_on_all_associations(:belongs_to)
        modifications = version.modifications
        original_modifications = modifications.deep_dup
        get_possible_id_keys_in_versions(modifications).each do |key|
          update_version_modification_key!(modifications, key, belongs_to_associations, version)
        end
        version.update_column(:object_changes, modifications.to_yaml) if original_modifications != modifications
      end
    end

    def get_possible_id_keys_in_versions(modifications)
      modifications.keys.select{|key| key.ends_with?("_id") || key.ends_with?("_by")}
    end

    def update_version_modification_key!(modifications, key, belongs_to_associations, version)
      association_class = get_association_for_foreign_key(key, belongs_to_associations, version)
      puts "ASSOCIATION CLASS IS NIL. #{key}: #{modifications}" && return if association_class.blank?
      association_class = association_class.constantize
      modifications[key] = get_new_ids_for_chronus_versions_hash(modifications, key, association_class)
    end

    def get_new_ids_for_chronus_versions_hash(modifications, key, association_class)
      new_ids = []
      modifications[key].each do |old_id|
        # If target_id for the old_id is not present then target_id will be 0.
        new_ids << (old_id.blank? ? old_id : get_new_id(old_id, association_class).to_i)
      end
      new_ids
    end

    def get_association_for_foreign_key(foreign_key, belongs_to_associations, version)
      action_item = get_association_for_action_item_id(version, foreign_key)
      return action_item if action_item.present?

      association = belongs_to_associations.select{|assoc| assoc.foreign_key == foreign_key}.first
      return unless association.present?
      if association.options[:polymorphic].present?
        version.reload.item.send(association.foreign_type.to_sym)
      else
        association.class_name
      end
    end

    def get_association_for_action_item_id(version, foreign_key)
      return if foreign_key != "action_item_id" || !["MentoringModel::TaskTemplate", "MentoringModel::Task"].include?(version.item_type)
      MentoringModel::TaskTemplate::ActionItem.action_item_name(version.reload.item.action_item_type).name
    end

    def migrate_campaigns
      get_ar_relation_for_source_audit_key(CampaignManagement::AbstractCampaign, get_source_audit_key("%"), {match_condition: "LIKE"}).where.not(trigger_params: nil).select(:id, :trigger_params).each do |campaign|
        old_trigger_params = campaign.trigger_params
        new_trigger_params = {}
        old_trigger_params.each do |key, old_ids|
          source_audit_keys = get_bulk_source_audit_keys(old_ids)
          new_ids = get_ids_with_source_audit_key(AbstractView, "(#{source_audit_keys})", {match_condition: "IN"})
          new_trigger_params[key] = new_ids
        end
        campaign.update_column(:trigger_params, new_trigger_params)
      end
    end

    def migrate_ancestry_models
      ANCESTRY_ASSOCIATED_MODELS.each do |model_name, column|
        model = model_name.constantize
        get_ar_relation_for_source_audit_key(model, get_source_audit_key("%"), {match_condition: "LIKE"}).where.not(column.to_sym => nil).select(:id, column.to_sym).each do |object|
          old_ancestry = object.send(column.to_sym)
          next if old_ancestry.blank?
          old_ids = old_ancestry.split("/")
          source_audit_keys = get_bulk_source_audit_keys(old_ids)
          new_ids = get_ids_with_source_audit_key(model, "(#{source_audit_keys})", {match_condition: "IN", order: "field(source_audit_key, #{source_audit_keys})"})
          object.update_column(column.to_sym, new_ids.join("/"))
        end
      end
    end
  end
end