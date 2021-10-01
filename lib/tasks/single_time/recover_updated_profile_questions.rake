namespace :single_time do

  #usage: bundle exec rake single_time:recover_updated_profile_questions
  desc "Recover wrongly updated profile questions"
  task recover_updated_profile_questions: :environment do

    COLUMNS_TO_UPDATE = ["question_info", "position", "section_id", "help_text", "allow_other_option", "options_count", "text_only_option"]
    INTEGER_COLUMNS = ["position", "section_id", "options_count"]
    BOOLEAN_COLUMNS = ["allow_other_option", "text_only_option"]

    not_deleted_question_choices_hash = {}
    deleted_question_choices_hash = {}
    Common::RakeModule::Utils.execute_task do
      programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization("chronus.com", "metlifementoring", "p2")
      program = programs[0]
      role_ids = program.role_ids
      csv_rows = CSV.read(ENV['FILE'], headers: true)
      modified_pq_ids = csv_rows.collect{|row| row["id"]}
      modified_pqs = organization.profile_questions.includes({default_question_choices: [:answer_choices]}).where(id: modified_pq_ids).index_by(&:id)

      csv_rows[1..-1].each do |row|
        pq = modified_pqs[row["id"].to_i]
        before_profile_answers_count = pq.profile_answers.count

        COLUMNS_TO_UPDATE.each do |column_name|
          value_to_restore = row[column_name]
          if column_name == "question_info"
            next unless pq.choice_or_select_type?
            texts = value_to_restore.split_by_comma
            pq.default_question_choices.each do |qc|
              next if texts.include?(qc.text)

              if qc.answer_choices.any?
                not_deleted_question_choices_hash[pq.id] ||= []
                not_deleted_question_choices_hash[pq.id] << qc.id
              else
                deleted_question_choices_hash[pq.id] ||= []
                deleted_question_choices_hash[pq.id] << qc.id
                qc.destroy
              end
            end
          else
            value_to_restore = if INTEGER_COLUMNS.include?(column_name)
              value_to_restore.try(:to_i)
            elsif BOOLEAN_COLUMNS.include?(column_name)
              value_to_restore.to_boolean
            else
              value_to_restore
            end
            pq.send("#{column_name}=", value_to_restore)
          end
        end
        pq.save!

        raise "#{pq.id} have profile answers mismatch" if before_profile_answers_count != pq.profile_answers.count
      end

    end
    Common::RakeModule::Utils.print_alert_messages("Non deleted question choices: #{not_deleted_question_choices_hash}")
    Common::RakeModule::Utils.print_success_messages("Deleted question choices: #{deleted_question_choices_hash}")
  end



end