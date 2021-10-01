module ChronusSftpFeed
  module Service
    class LocationUpdater < ChronusSftpFeed::Service::BaseUpdater
      def initialize(config, options = {})
        super(config, options)
        @location_map = options[:location_map] || {}
        initialize_mapping
      end

      def self.fetch_location_map(config, total_chunks)
        location_map = {}
        location_texts = total_chunks.map{|chunk| chunk.map{|record| record[config.secondary_questions_map[ProfileQuestion::Type::LOCATION.to_s]]}}.flatten.uniq - [nil]
        location_texts.each do |location_text|
          # The following change is required, because find_or_create_by_full_address mutates the sent param, which defies the purpose of location_map.
          # e.g. if 'Chennai, IN' is sent as param, the method changes it to 'Chennai IN' - stripping the comma.
          location = location_text.dup
          location_map[location_text] ||= Location.find_or_create_by_full_address(location)
        end
        location_map
      end

      private

      def update_record(record, record_index)
        primary_key = get_primary_key(record)
        member = @members_map[primary_key]

        begin
          return if primary_key.blank? || @duplicate_keys.include?(primary_key) || member.blank?

          answer_value = record[@question.question_text]
          return if answer_value.blank? && @answers_map[member.id].blank?

          if answer_value.present?
            profile_answer = @answers_map[member.id] || member.profile_answers.build(profile_question: @question)
            return if profile_answer.location.present? && (answer_value == profile_answer.location.full_address)

            location = @location_map[answer_value] || Location.find_or_create_by_full_address(answer_value)
            if location != profile_answer.location
              profile_answer.location = location
              save_record!(profile_answer)
              push_logger_data(member, record_index)
            end
          else
            @answers_map[member.id].destroy
          end
        rescue => error
          @error_data << [record_index, "#{primary_key}", "#{@question.question_text}", "#{answer_value}", error.message.gsub(/Validation failed: /,'')]
          ChronusSftpFeed::Migrator.logger "#{@error_data.last.join(", ")}\n"
        end
      end

      def initialize_mapping
        members_scope = initialize_members_map
        @question = @organization.profile_questions.joins(:translations).where("profile_question_translations.locale = ? AND profile_question_translations.question_text = ? AND question_type = ?", I18n.default_locale.to_s, @config.secondary_questions_map[ProfileQuestion::Type::LOCATION.to_s], ProfileQuestion::Type::LOCATION).first
        return if @question.blank?
        @answers_map = {}
        PerfUtils.table_for_join("temp_location_members", (members_scope || []).collect(&:id)) do |temp_table|
          answers_scope = ProfileAnswer.joins("RIGHT JOIN #{temp_table} ON profile_answers.ref_obj_id = #{temp_table}.id").where(ref_obj_type: Member.name, profile_question_id: @question.id)
          answers_scope.find_each do |answer|
            @answers_map[answer.ref_obj_id] = answer
          end
        end
      end
    end
  end
end
