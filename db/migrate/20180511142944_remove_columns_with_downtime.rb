class RemoveColumnsWithDowntime < ActiveRecord::Migration[5.1]
  TABLE_TRANSLATED_COLUMNS_MAP = {
    "programs" => { name: "varchar(255)", description: "text", allow_mentoring_requests_message: "text", agreement: "longtext", privacy_policy: "text", browser_warning: "text", zero_match_score_message: "text" },
    "mentoring_models" => { title: "varchar(255)", description: "text", forum_help_text: "text" },
    "mentoring_model_task_templates" => { title: "varchar(255)", description: "text" },
    "mentoring_model_goals" => { title: "varchar(255)", description: "text" },
    "mentoring_model_goal_templates" => { title: "varchar(255)", description: "text" },
    "mentoring_model_milestones" => { title: "varchar(255)", description: "text" },
    "mentoring_model_milestone_templates" => { title: "varchar(255)", description: "text" },
    "mentoring_model_facilitation_templates" => { subject: "varchar(255)", message: "text" },
    "roles" => { description: "text", eligibility_message: "text" },
    "pages" => { title: "varchar(255)", content: "longtext" },
    "profile_questions" => { question_text: "text", help_text: "text", conditional_match_text: "varchar(255)", question_info: "text" },
    "question_choices" => { text: "text" },
    "cm_campaigns" => { title: "varchar(255)" },
    "instructions" => { content: "text" },
    "announcements" => { title: "varchar(255)", body: "longtext" },
    "auth_configs" => { title: "varchar(255)", password_message: "text" },
    "auth_config_settings" => { default_section_title: "varchar(255)", default_section_description: "text", custom_section_title: "varchar(255)", custom_section_description: "text" },
    "common_questions" => { question_text: "text", help_text: "text", question_info: "text" },
    "contact_admin_settings" => { label_name: "varchar(255)", content: "text" },
    "customized_terms" => { term: "varchar(255) NOT NULL", term_downcase: "varchar(255) NOT NULL", pluralized_term: "varchar(255) NOT NULL", pluralized_term_downcase: "varchar(255) NOT NULL", articleized_term: "varchar(255) NOT NULL", articleized_term_downcase: "varchar(255) NOT NULL" },
    "surveys" => { name: "varchar(255)" },
    "group_closure_reasons" => { reason: "varchar(255)" },
    "mailer_templates" => { subject: "text", source: "text" },
    "mailer_widgets" => { source: "text" },
    "program_assets" => { logo_file_name: "varchar(255)", logo_content_type: "varchar(255)", logo_file_size: "int(11)", banner_file_name: "varchar(255)", banner_content_type: "varchar(255)", banner_file_size: "int(11)" },
    "program_events" => { title: "varchar(255)", description: "text" },
    "resources" => { title: "varchar(255)", content: "text" },
    "sections" => { title: "varchar(255)", description: "text" },
    "three_sixty_competencies" => { title: "varchar(255) NOT NULL", description: "text" },
    "three_sixty_questions" => { title: "text DEFAULT '' NOT NULL" }
  }

  def up
    ChronusMigrate.data_migration do
      TABLE_TRANSLATED_COLUMNS_MAP.each do |table_name, columns|
        Lhm.change_table table_name do |t|
          columns.keys.each do |column_name|
            rows = ActiveRecord::Base.connection.exec_query("SHOW COLUMNS FROM `#{table_name}` LIKE '#{column_name}';").rows
            next if rows.flatten.blank?
            t.remove_column column_name
          end
        end
      end

      Lhm.change_table "membership_requests" do |t|
        rows = ActiveRecord::Base.connection.exec_query("SHOW COLUMNS FROM `membership_requests` LIKE 'deleted_at';").rows
        t.remove_column :deleted_at unless rows.flatten.blank?
      end
    end
  end

  def down
    ChronusMigrate.data_migration do
      Lhm.change_table "membership_requests" do |t|
        t.add_column :deleted_at, :datetime
      end
      TABLE_TRANSLATED_COLUMNS_MAP.each do |table_name, columns|
        Lhm.change_table table_name do |t|
          columns.each do |column_name, column_spec|
            t.add_column column_name, column_spec
          end
        end
      end
    end
  end
end
