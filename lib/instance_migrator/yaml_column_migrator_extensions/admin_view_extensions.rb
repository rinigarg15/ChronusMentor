module InstanceMigrator
  module YamlColumnMigratorExtensions
    module AdminViewExtensions

      def migrate_admin_view
        get_ar_relation_for_source_audit_key(AdminView, get_source_audit_key("%"), {match_condition: "LIKE"}).where.not(filter_params: nil).select(:id, :filter_params).each do |admin_view|
          yaml_filter_params = admin_view.filter_params_hash
          yaml_filter_params = handle_profile_questions_in_admin_view(yaml_filter_params)
          yaml_filter_params = handle_surveys_in_admin_view(yaml_filter_params)
          yaml_filter_params = handle_language_in_admin_view(yaml_filter_params)
          yaml_filter_params = handle_program_role_state_in_admin_view(yaml_filter_params)
          admin_view.update_column(:filter_params, yaml_filter_params.to_yaml)
        end
      end

      def handle_surveys_in_admin_view(yaml_filter_params)
        return yaml_filter_params unless yaml_filter_params["survey"].present?
        update_survey_id_in_user_filter!(yaml_filter_params)
        handle_survey_questions_in_admin_view(yaml_filter_params)
      end

      def update_survey_id_in_user_filter!(yaml_filter_params)
        return if yaml_filter_params["survey"]["user"].blank? || yaml_filter_params["survey"]["user"]["survey_id"].blank?
        yaml_filter_params["survey"]["user"]["survey_id"] = get_new_id(yaml_filter_params["survey"]["user"]["survey_id"], Survey).to_s
      end

      def handle_survey_questions_in_admin_view(yaml_filter_params)
        (yaml_filter_params["survey"]["survey_questions"] || {}).each do |key, value|
          update_survey_id_in_survey_question_filter!(yaml_filter_params, key, value)
          update_survey_question_id_in_survey_question_filter!(yaml_filter_params, key, value)
          update_choice_id_in_survey_question_filter!(yaml_filter_params, key, value)
        end
        yaml_filter_params
      end

      def update_survey_id_in_survey_question_filter!(yaml_filter_params, key, value)
        return if value["survey_id"].blank?
        yaml_filter_params["survey"]["survey_questions"][key]["survey_id"] = get_new_id(value['survey_id'], Survey).to_s
      end

      def update_survey_question_id_in_survey_question_filter!(yaml_filter_params, key, value)
        return  if value["question"].blank? || value["question"] == "answers"
        yaml_filter_params["survey"]["survey_questions"][key]["question"] = "answers#{get_new_id(value['question'].split('answers').last, SurveyQuestion)}"
      end

      def update_choice_id_in_survey_question_filter!(yaml_filter_params, key, value)
        return if value["choice"].blank?
        yaml_filter_params["survey"]["survey_questions"][key]["choice"] = get_new_choice_ids(value["choice"], CommonQuestion.name)
      end

      def handle_profile_questions_in_admin_view(yaml_filter_params)
       return yaml_filter_params unless yaml_filter_params["profile"].present?
        (yaml_filter_params["profile"]["questions"] || {}).each do |key, value|
          update_profile_question_in_profile_filter!(yaml_filter_params, key, value)
          update_choice_id_in_profile_filter!(yaml_filter_params, key, value)
        end
        yaml_filter_params
      end

      def update_profile_question_in_profile_filter!(yaml_filter_params, key, value)
        return if value["question"].blank?
        yaml_filter_params["profile"]["questions"][key]["question"] = get_new_id(value['question'], ProfileQuestion).to_s
      end

      def update_choice_id_in_profile_filter!(yaml_filter_params, key, value)
        return if value["choice"].blank?
        yaml_filter_params["profile"]["questions"][key]["choice"] = get_new_choice_ids(value["choice"], ProfileQuestion.name)
      end

      def handle_language_in_admin_view(yaml_filter_params)
        return yaml_filter_params  unless yaml_filter_params["language"].present?
        yaml_filter_params["language"] = yaml_filter_params["language"].collect {|l_id| get_language_id(l_id).to_s}
        yaml_filter_params
      end

      def get_language_id(l_id)
        return l_id if l_id == "0"
        ActiveRecord::Base.connection.execute("select target_j_id from temp_common_join_table where source_j_id=#{l_id} AND table_name='languages'").to_a.flatten.first
      end

      def handle_program_role_state_in_admin_view(yaml_filter_params)
        return yaml_filter_params if yaml_filter_params["program_role_state"].blank? || yaml_filter_params["program_role_state"]["filter_conditions"].blank?
        yaml_filter_params["program_role_state"]["filter_conditions"].each do |_parent_filter, child_filters|
          update_program_ids_in_child_filters!(child_filters)
        end
        yaml_filter_params
      end

      def update_program_ids_in_child_filters!(child_filters)
        child_filters.each do |_key, value|
          value["program"] = get_program_ids(value) if value["program"].present?
        end
      end

      def get_program_ids(child_filter)
        program_ids = child_filter["program"]
        get_ids_with_source_audit_key(Program, "(#{get_bulk_source_audit_keys(program_ids)})", {match_condition: "IN"}).collect(&:to_s)
      end
    end
  end
end