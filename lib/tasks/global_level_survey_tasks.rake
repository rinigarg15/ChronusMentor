namespace :global do
  desc 'Generate report for survey in all programs'
  task generate_org_level_survey_report: :environment do
    start_time = Time.now
    organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV['DOMAIN'], ENV['SUBDOMAIN'])[1]
    locale = ENV["LOCALE"] || I18n.default_locale
    survey_name = ENV['SURVEYNAME']
    program_ids = organization.programs.pluck(:id)
    surveys = Survey.where(program_id: program_ids, name: survey_name).includes(:translations, program: :translations)
    output_file = File.open("#{survey_name.to_html_id}_responses_#{Time.now.to_i.to_s}.xls", 'w')
    book = Spreadsheet::Workbook.new
    sheet = book.create_worksheet
    sheet.name = "feature.survey.survey_report.Grouped_by_member".translate
    options = { book: book, sheet: sheet, aggrigate_not_needed: true }
    headers_not_needed = false
    row_number = 1

    surveys.each do |survey|
      options.merge!( headers_not_needed: headers_not_needed, row_number: row_number )
      SurveyResponsesXlsDataService.new(survey, survey.program, organization, locale, survey.responses.keys, additional_column_keys: [SurveyResponseColumn::Columns::Program]).build_xls_data_for_survey(options)
      row_number = sheet.row_count
      puts "#{row_number}"
      headers_not_needed = true
    end
    data = StringIO.new ''
    book.write data
    output_file.write data.string.force_encoding("UTF-8")
    output_file.close
    puts "Total time taken : #{Time.now - start_time}"
  end

  # Usage: bundle exec rake global:delete_surveys_across_tracks SURVEY_NAMES='survey1,survey2' DOMAIN='domain.com' SUBDOMAIN='subdomain' SKIP_ACTIVE_GROUPS=''
  desc "Delete surveys across tracks"
  task delete_surveys_across_tracks: :environment do
    Common::RakeModule::Utils.execute_task(async_dj: true) do
      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV['DOMAIN'], ENV['SUBDOMAIN'])[1]
      survey_names = ENV["SURVEY_NAMES"].split(",").map(&:strip)

      survey_ids = organization.programs.joins(:surveys).where(surveys: { name: survey_names }).select("surveys.id AS survey_id").collect(&:survey_id)
      raise "Could not find survey with given names" if survey_ids.empty?

      handle_associated_tasks_for(survey_ids, ENV['SKIP_ACTIVE_GROUPS'].to_s.to_boolean)
      Survey.where(id: survey_ids).destroy_all
      Common::RakeModule::Utils.print_success_messages("Surveys deleted Successfully!")
    end
  end

  # Usage: bundle exec rake global:clone_survey_questions_across_tracks DOMAIN="chronus.com" SUBDOMAIN="walkthru" SOURCE_PROGRAM_ROOT="p1" TARGET_ROOTS="p2,p3"<optional> SOURCE_SURVEY_IDS='1,2' FORCE_DELETION=true|false SKIP_ROOTS="p4"<optional> CREATE_SURVEY=true<optional> DUE_DATE="21-07-2018"<optional> SKIP_CREATION_IF_SURVEY_EXISTS=true<optional>
  desc "Clone Survey Questions From Survey in Master Program to Surveys in Other Tracks"
  task clone_survey_questions_across_tracks: :environment do
    Common::RakeModule::Utils.execute_task do
      programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV['DOMAIN'], ENV['SUBDOMAIN'], ENV['SOURCE_PROGRAM_ROOT'])
      source_program = programs[0]

      target_programs = organization.programs.where.not(id: source_program.id).includes(surveys: [:translations, survey_questions: [:rating_questions, :question_choices]])

      target_programs = target_programs.where(root: ENV["TARGET_ROOTS"].split(",")) if ENV["TARGET_ROOTS"].present?
      target_programs = target_programs.where.not(root: ENV["SKIP_ROOTS"].split(",")) if ENV["SKIP_ROOTS"].present?

      source_survey_ids = ENV["SOURCE_SURVEY_IDS"].split(",").map(&:to_i)
      source_surveys = source_program.surveys.where(id: source_survey_ids)
      if source_survey_ids.size != source_surveys.size
        raise "Source surveys with ids #{source_survey_ids - source_surveys.collect(&:id)} not present"
      end

      source_surveys.each do |source_survey|
        target_programs.each do |target_program|
          target_survey = target_program.surveys.find{|survey| survey.name == source_survey.name  && survey.type == source_survey.type}
          next if ENV["SKIP_CREATION_IF_SURVEY_EXISTS"].to_s.to_boolean && target_survey.present?
          if ENV["CREATE_SURVEY"].to_s.to_boolean
            target_survey ||= source_survey.dup_with_translations
            target_survey.program = target_program
            target_survey.total_responses = 0
            if target_survey.program_survey?
              target_survey.due_date =  if ENV["DUE_DATE"].present?
                                          Date.parse(ENV["DUE_DATE"])
                                        else
                                          source_survey.due_date
                                        end
              target_survey.recipient_role_names = source_survey.recipient_role_names
            elsif target_survey.engagement_survey?
              target_survey.progress_report = if !target_program.share_progress_reports_enabled?
                                                false
                                              else
                                                source_survey.progress_report
                                              end
            end
            target_survey.form_type = nil
            target_survey.save!
          elsif target_survey.blank?
            raise "Target survey is not found for program #{target_program.root}"
          end
          force_destroy_existing_questions(target_survey, ENV["FORCE_DELETION"].to_s.to_boolean)
          clone_questions(source_survey, target_survey, target_program)
          Common::RakeModule::Utils.print_success_messages("Cloned survey questions successfully for survey #{source_survey.name} in program #{target_program.root}")
        end
      end
    end
  end

  private

  def force_destroy_existing_questions(target_survey, force_deletion = false)
    if !force_deletion && target_survey.survey_questions.any?{|sq| sq.survey_answers.any?}
      raise "Survey present in program #{target_survey.program.root} have responses!!"
    end
    target_survey.survey_questions.destroy_all
  end

  def clone_questions(source_survey, target_survey, target_program)
    source_survey.survey_questions.each do |q|
      q_dup = q.dup_with_translations
      q_dup.program = target_program
      q_dup.survey = target_survey
      q_dup.positive_outcome_options = nil
      q_dup.positive_outcome_options_management_report = nil
      if q.matrix_question_type?
        q.rating_questions.map(&:dup_with_translations).each do |rq|
          rq.program = target_program
          rq.matrix_question = q_dup
          rq.survey = target_survey
          rq.positive_outcome_options = nil
          rq.positive_outcome_options_management_report = nil
          q_dup.rating_questions << rq
        end
      end
      if q.choice_or_select_type?
        q.question_choices.map(&:dup_with_translations).each do |qc|
          qc.ref_obj = q_dup
          q_dup.question_choices << qc
        end
      end
      target_survey.survey_questions << q_dup
    end
  end

  def handle_associated_tasks_for(survey_ids, skip_active_groups)
    associated_task_templates = MentoringModel::TaskTemplate.where(action_item_id: survey_ids, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY)
    if associated_task_templates.present?
      details = associated_task_templates.joins(mentoring_model: :program).pluck("mentoring_model_task_templates.title, mentoring_models.title, programs.name")
      Common::RakeModule::Utils.print_alert_messages("Following task templates will get deleted")
      Common::RakeModule::Utils.print_alert_messages(details.map { |detail| "Task template: #{detail[0]} | Mentoring Model: #{detail[1]} | Program: #{detail[2]}" })

      unless skip_active_groups
        active_group_model_ids = associated_task_templates.joins(mentoring_model_tasks: :group)
          .where(groups: { status: Group::Status::ACTIVE_CRITERIA })
          .pluck("mentoring_model_task_templates.mentoring_model_id")
        if active_group_model_ids.uniq.compact.present?
          Common::RakeModule::Utils.print_error_messages("Model ID(s) with active groups: #{active_group_model_ids}")
          raise Common::RakeModule::Utils.print_error_messages("Active groups are having given survey(s) as a task. Please pass SKIP_ACTIVE_GROUPS if you are sure to delete.")
        end
      end

      associated_task_templates.destroy_all
      Common::RakeModule::Utils.print_success_messages("Task templates deleted Successfully!")
    end
  end
end