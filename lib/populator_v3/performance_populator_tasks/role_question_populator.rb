  class RoleQuestionPopulator < PopulatorTask
  def patch(options = {})
    roles_count = @program.roles.where(administrative: false).count
    @counts_ary = [roles_count]
    @percents_ary = [100]
    profile_question_ids = @program.organization.profile_question_ids
    role_question_hsh = get_children_hash(@program, @options[:args]["model"]||@node, @foreign_key, profile_question_ids)
    process_patch(profile_question_ids, role_question_hsh)
  end

  def add_role_questions(profile_question_ids, count, options = {})
    self.class.benchmark_wrapper "Role questions" do
      program = options[:program]
      role_ids = program.roles.where(administrative: false).pluck(:id)
      name_question_id = program.organization.name_question.id
      role_ques_private_types = (RoleQuestion::PRIVACY_SETTING.all + [RoleQuestion::PRIVACY_SETTING::ALL, RoleQuestion::PRIVACY_SETTING::RESTRICTED] * 2).shuffle
      role_ques_privacy_settings = RoleQuestionPrivacySetting.restricted_privacy_setting_options_for(program).shuffle
      profile_question_ids.each do |question_id|
        count.times do
          RoleQuestion.populate 1 do |role_ques|
            profile_question_role_pair_exit = false
            role_id = nil
            # getting uniq pair of profile question and role
            role_ids.count do
              role_id = role_ids.first
              role_ids = role_ids.rotate
              profile_question_role_pair_exit = validate_profile_question_role_pair(question_id, role_id, program)
              break if profile_question_role_pair_exit
            end
            next unless profile_question_role_pair_exit
            role_ques.required = [false, true].sample
            role_ques.filterable = true
            role_ques.private = if name_question_id == question_id
              RoleQuestion::PRIVACY_SETTING::ALL
            else
              role_ques_private_types.first
              role_ques_private_types = role_ques_private_types.rotate
            end

            role_ques.available_for = (RoleQuestion::AVAILABLE_FOR.all + [RoleQuestion::AVAILABLE_FOR::BOTH, RoleQuestion::AVAILABLE_FOR::BOTH]).sample
            role_ques.profile_question_id = question_id
            role_ques.role_id = role_id
            RoleQuestionPrivacySetting.populate 1 do |privacy_setting|
              privacy_setting_params = (role_ques_privacy_settings.rotate!.first)[:privacy_setting]
              privacy_setting.setting_type = privacy_setting_params[:setting_type]
              privacy_setting.role_id = privacy_setting_params[:role_id]
              privacy_setting.role_question_id = role_ques.id
            end
          end
          self.dot
        end
      end
      self.class.display_populated_count(profile_question_ids.size * role_ids.count, "Role Question")
    end
  end

  def remove_role_questions(profile_question_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Role questions....." do
      program = options[:program]
      role_question_ids = program.role_questions.where(:profile_question_id => profile_question_ids).select("profile_question_id, role_questions.id").group_by(&:profile_question_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      RoleQuestionPrivacySetting.where(role_question_id: role_question_ids).destroy_all
      program.role_questions.where(:id => role_question_ids).destroy_all
      self.class.display_deleted_count(profile_question_ids.size * count, "Role Question")
    end
  end

  def validate_profile_question_role_pair(question_id, role_id, program)
    program.role_questions.where(:profile_question_id => question_id, :role_id => role_id).count.zero? ? true : false
  end
end