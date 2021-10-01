module ChronusSftpFeed
  module Service
    class ManagerUpdater < ChronusSftpFeed::Service::BaseUpdater
      def initialize(config, options = {})
        super(config, options)
        initialize_mapping
      end

      def run
        super if @question.present?
      end

      private

      def update_record(record, record_index)
        primary_key = get_primary_key(record)
        member = @members_map[primary_key]

        begin
          return if primary_key.blank? || @duplicate_keys.include?(primary_key) || member.blank?

          manager_detail = build_manager_details(record) || []
          return if @answers_map[member.id].blank? && manager_detail.select{|x| !x.blank?}.blank?
          raise "Invalid manager detail #{manager_detail}" if manager_detail.size != 3

          manager_detail[2] = manager_detail[2].try(:downcase)
          raise "Member email and manager email are same" if manager_detail[2] == member.email

          update_manager(member, manager_detail)
          push_logger_data(member, record_index)
        rescue => error
          @error_data << [record_index, "#{primary_key}", "#{@question.question_text}", "#{manager_detail}", error.message.gsub(/Validation failed: /,'')]
          ChronusSftpFeed::Migrator.logger "#{@error_data.last.join(", ")}\n"
        end
      end

      def build_manager_details(record)
        return record[@question.question_text].split(",").collect(&:strip) if record[@question.question_text].present?

        data_columns = @config.supplement_questions_map[@question.question_text]
        return if data_columns.nil?

        details = {}
        data_columns.each do |column_name, attr_name|
          details[attr_name] = record[column_name]
        end
        [details[:first_name], details[:last_name], details[:email]]
      end

      def initialize_mapping
        members_scope = initialize_members_map

        @question = @organization.profile_questions.joins(:translations).where("profile_question_translations.locale = ? AND profile_question_translations.question_text = ? AND question_type = ?", I18n.default_locale.to_s, @config.secondary_questions_map[ProfileQuestion::Type::MANAGER.to_s], ProfileQuestion::Type::MANAGER.to_s).first
        return if @question.blank?

        @answers_map = {}
        answers_scope = ProfileAnswer.where(ref_obj_type: Member.name, ref_obj_id: members_scope.map(&:id), profile_question_id: @question.id)
        answers_scope.find_each do |answer|
          @answers_map[answer.ref_obj_id] = answer
        end
      end

      def update_manager(member, manager_detail)
        profile_answer = @answers_map[member.id]
        if manager_detail.select{|x| !x.blank?}.present?
          profile_answer ||= member.profile_answers.build(profile_question: @question)
          manager = Manager.new(first_name: manager_detail[0], last_name: manager_detail[1], email: manager_detail[2])
          if profile_answer.answer_text != "#{manager.full_data}"
            unless profile_answer.new_record?
              Manager.where(:profile_answer_id => profile_answer.id).destroy_all
              profile_answer.destroy
              profile_answer = member.profile_answers.build(:profile_question_id => @question.id)
            end
            profile_answer.answer_text = "#{manager.full_data}"
            manager.profile_answer = profile_answer
            save_record!(profile_answer)
          end
        elsif profile_answer.present?
          profile_answer.destroy
          @updated = true
        end
      end
    end
  end
end