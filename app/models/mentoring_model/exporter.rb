class MentoringModel::Exporter

  module MentoringTemplate
    HEADER = [
      "feature.mentoring_model.header.goal_progress_type".translate,
      "feature.mentoring_model.header.alter_admin_created_tasks".translate,
      "feature.mentoring_model.label.enable_messaging".translate,
      "feature.mentoring_model.label.enable_discussion_board".translate,
      "feature.mentoring_model.content.discussion_board_message_help_text".translate,
    ]

    module GoalType
      MANUAL = "Manual"
      AUTO = "Auto"
    end

    module Status
      ENABLED = "display_string.Enabled".translate
      DISABLED = "display_string.Disabled".translate
    end
  end

  module GoalTemplate
    HEADER = ["feature.mentoring_model.header.Title".translate, "feature.mentoring_model.header.Description".translate]
  end

  module MilestoneTemplate
    HEADER = ["feature.mentoring_model.header.Title".translate, "feature.mentoring_model.header.Description".translate, "feature.mentoring_model.header.position".translate]
  end

  module TaskTemplate
    HEADER = ["feature.mentoring_model.header.Title".translate, 
              "feature.mentoring_model.header.Description".translate,
              "feature.mentoring_model.header.required".translate,
              ->(details){"feature.mentoring_model.header.due_date_label".translate(details)},
              "feature.mentoring_model.header.after".translate,
              ->(details) {"feature.mentoring_model.header.action_item_header".translate(details)},
              "feature.mentoring_model.header.action_item_id_header".translate,
              ->(details){"feature.mentoring_model.header.assignee_prn".translate(details)},
              "feature.mentoring_model.header.task_goal_header".translate,
              "feature.mentoring_model.header.task_milestone_header".translate,
              "feature.mentoring_model.header.task_specific_date".translate]
    ACTION_ITEM_TYPE = ["none", MentoringModel::Importer::TaskTemplate::ActionItemIdentifier::MEETING, MentoringModel::Importer::TaskTemplate::ActionItemIdentifier::GOAL, "", MentoringModel::Importer::TaskTemplate::ActionItemIdentifier::ENGAGEMENT_SURVEY]
    def self.get_header(details)
      HEADER.collect{|header| header.is_a?(String) ? header : header.call(details)}
    end
  end

  module FacilitationTemplate
    HEADER = ["feature.mentoring_model.header.subject".translate, "feature.mentoring_model.header.content".translate, "feature.mentoring_model.header.for".translate, "feature.mentoring_model.header.send_after_days".translate, "feature.mentoring_model.header.milestone".translate, "feature.mentoring_model.header.specific_date".translate]
  end

  def export(mentoring_model, file_path = "mentoring_model_export.csv")
    goal_templates = mentoring_model.mentoring_model_goal_templates
    task_templates = mentoring_model.mentoring_model_task_templates.includes(:role, :milestone_template)
    milestone_templates = mentoring_model.mentoring_model_milestone_templates
    facilitation_templates = mentoring_model.mentoring_model_facilitation_templates.includes(:roles, :milestone_template)

    csv_generator_method = file_path ? [:open, file_path, "wb"] : [:generate]
    CSV.send(*csv_generator_method) do |csv|
      csv << [MentoringModel::Importer::MentoringTemplate::BLOCK_IDENTIFIER]
      csv << MentoringModel::Exporter::MentoringTemplate::HEADER
      csv << mentoring_template_csv_content(mentoring_model)
      csv << []

      if goal_templates.present?
        csv << [MentoringModel::Importer::GoalTemplate::BLOCK_IDENTIFIER]
        csv << MentoringModel::Exporter::GoalTemplate::HEADER
        goal_templates.each do |goal_template|
          csv_header = goal_template_csv_content(goal_template)
          csv << csv_header
        end
        csv << []
      end
      if milestone_templates.present?
        csv << [MentoringModel::Importer::MilestoneTemplate::BLOCK_IDENTIFIER]
        csv << MentoringModel::Exporter::MilestoneTemplate::HEADER
        milestone_templates.each do |milestone_template|
          csv_header = milestone_template_csv_content(milestone_template)
          csv << csv_header
        end
        csv << []
      end
      if task_templates.present?
        csv << [MentoringModel::Importer::TaskTemplate::BLOCK_IDENTIFIER]
        program = mentoring_model.program
        terms = program.customized_terms
        program_role_names = RoleConstants.program_roles_mapping(program, :roles => program.roles.for_mentoring).values.join(", ")
        csv << MentoringModel::Exporter::TaskTemplate.get_header({prn: program_role_names, :Meeting => terms.find_by(term_type: CustomizedTerm::TermType::MEETING_TERM).term, :Mentoring_Connection => terms.find_by(term_type: CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term, mentoring_connection: terms.find_by(term_type: CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase})
        task_templates.each do |task_template|
          csv_header = task_template_csv_content(task_template)
          csv << csv_header
        end
        csv << []
      end
      if facilitation_templates.present?
        csv << [MentoringModel::Importer::FacilitationMessageTemplate::BLOCK_IDENTIFIER]
        csv << MentoringModel::Exporter::FacilitationTemplate::HEADER
        facilitation_templates.each do |facilitation_template|
          csv_header = facilitation_template_csv_content(facilitation_template)
          csv << csv_header
        end
        csv << []
      end
    end
  end

  private

  def mentoring_template_csv_content(mentoring_model)
    [
      (mentoring_model.manual_progress_goals? ? MentoringTemplate::GoalType::MANUAL : MentoringTemplate::GoalType::AUTO),
      (mentoring_model.allow_due_date_edit? ? MentoringTemplate::Status::ENABLED : MentoringTemplate::Status::DISABLED),
      (mentoring_model.allow_messaging? ? MentoringTemplate::Status::ENABLED : MentoringTemplate::Status::DISABLED),
      (mentoring_model.allow_forum? ? MentoringTemplate::Status::ENABLED : MentoringTemplate::Status::DISABLED),
      mentoring_model.forum_help_text
    ]
  end

  def goal_template_csv_content(goal_template)
    [goal_template.title, goal_template.description.to_s]
  end

  def milestone_template_csv_content(milestone_template)
    [milestone_template.title, milestone_template.description.to_s, milestone_template.position]
  end

  def task_template_csv_content(task_template)
    task_template_row = []
    task_template_required_text = task_template.required ? "display_string.Yes".translate : "display_string.No".translate
    task_template_associated_title = task_template.required ? (task_template.associated_task.try(:title) || MentoringModel::Importer::TaskTemplate::START_OF_CONNECTION_IDENTIFIER) : ""
    task_template_goal_title = task_template.goal_template.try(:title) || ""
    task_template_milestone_title = task_template.milestone_template.try(:title) || ""
    role_capitalized_text =  RoleConstants.to_program_role_names(task_template.mentoring_model.program,[(task_template.role.try(:name) || "")]).first.capitalize
    # The gsub method needs to be cleaned up, once we upgrade CKEditor
    task_template_description_text = task_template.description.present? ? task_template.description.gsub("\r\n", "") : ""
    task_template_row << task_template.title
    task_template_row << task_template_description_text
    task_template_row << task_template_required_text
    task_template_row << task_template.duration.to_s
    task_template_row << task_template_associated_title
    task_template_row << MentoringModel::Exporter::TaskTemplate::ACTION_ITEM_TYPE[task_template.action_item_type]
    task_template_row << task_template.action_item_id
    task_template_row << role_capitalized_text
    task_template_row << task_template_goal_title
    task_template_row << task_template_milestone_title
    task_template_row << task_template.specific_date.try(:to_date).try(:strftime, '%m/%d/%Y').to_s
    task_template_row
  end

  def facilitation_template_csv_content(facilitation_template)
    facilitation_template_row = []
    # The gsub method needs to be cleaned up, once we upgrade CKEditor
    facilitation_template_message_text = facilitation_template.message.present? ? facilitation_template.message.gsub("\r\n", "") : ""
    milestone_template_text = facilitation_template.milestone_template.try(:title) || ""
    facilitation_template_row << facilitation_template.subject
    facilitation_template_row << facilitation_template_message_text
    facilitation_template_row << RoleConstants.to_program_role_names(facilitation_template.mentoring_model.program, facilitation_template.role_names).join(MentoringModel::Importer::ROLE_DELIMITER)
    facilitation_template_row << facilitation_template.send_on.to_s
    facilitation_template_row << milestone_template_text
    facilitation_template_row << facilitation_template.specific_date.try(:to_date).try(:strftime, '%m/%d/%Y').to_s if facilitation_template.specific_date.present?
    facilitation_template_row
  end
end
