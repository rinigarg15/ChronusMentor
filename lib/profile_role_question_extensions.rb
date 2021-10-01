module ProfileRoleQuestionExtensions

  private

  def default_role_params(question_type)
    if (question_type == ProfileQuestion::Type::EMAIL)
      default_hash = {:in_summary => false, :required => true, :filterable => false, :admin_only_editable => false}
    elsif (question_type == ProfileQuestion::Type::NAME)
      default_hash = {:in_summary => true, :required => true, :filterable => true, :admin_only_editable => false}
    else
      default_hash = {:in_summary => false, :required => false, :filterable => false, :admin_only_editable => false}
    end
  end

  def embed_additional_attrs(profile_question, role_id, role_question, role_questions = {})
    rq_attrs = role_questions[role_id] || {}
    privacy_setting_attrs = rq_attrs.delete("privacy_settings") || {}

    if role_id.present?
      program = Role.find(role_id).program
      rq_attrs[:private] = build_associated_privacy_settings(program, role_question, privacy_setting_attrs)
    else
      rq_attrs[:private] = role_question.private
    end

    if profile_question.non_default_type? && (rq_attrs[:admin_only_editable] == 'true' || rq_attrs[:private] == RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
      rq_attrs[:available_for] = RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS
      rq_attrs[:admin_only_editable] = true
    elsif rq_attrs[:available_for].present?
      if rq_attrs[:available_for][:profile].present? && rq_attrs[:available_for][:membership_form].present?
        rq_attrs[:available_for] = RoleQuestion::AVAILABLE_FOR::BOTH
      elsif rq_attrs[:available_for][:profile].present?
        rq_attrs[:available_for] = RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS
      else
        rq_attrs[:available_for] = RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS
      end
    end
    rq_attrs.reverse_merge(default_role_params(profile_question.question_type))
  end

  def build_associated_privacy_settings(program, role_question, privacy_setting_attrs)
    privacy_setting_attrs = pre_process_privacy_attrs(privacy_setting_attrs)

    new_privacy_setting_types = privacy_setting_attrs.collect(&:first)
    if new_privacy_setting_types.include? RoleQuestion::PRIVACY_SETTING::RESTRICTED
      new_restricted_privacy_setting_attrs = privacy_setting_attrs.select{|ps_attr| ps_attr.first == RoleQuestion::PRIVACY_SETTING::RESTRICTED}.collect(&:last)
      if (restricted_privacy_setting_options(program) - new_restricted_privacy_setting_attrs).blank?
        return RoleQuestion::PRIVACY_SETTING::ALL
      else
        update_associated_privacy_settings(role_question, new_restricted_privacy_setting_attrs)
        return RoleQuestion::PRIVACY_SETTING::RESTRICTED
      end
    elsif new_privacy_setting_types.include? RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
      return RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
    elsif role_question.profile_question.name_type?
      # Name question by default is viewable to all and the visibility is non-editable
      return RoleQuestion::PRIVACY_SETTING::ALL
    else
      return RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    end
  end

  def update_associated_privacy_settings(role_question, restricted_privacy_setting_attrs)
    role_question.privacy_settings.each do |existing_setting|
      existing_setting.destroy unless restricted_privacy_setting_attrs.include?({setting_type: existing_setting.setting_type, role_id: existing_setting.role_id})
    end
    restricted_privacy_setting_attrs.each do |new_privacy_setting|
      existing_privacy_setting = role_question.privacy_settings.find do |privacy_setting|
        privacy_setting.setting_type == new_privacy_setting[:setting_type] && privacy_setting.role_id == new_privacy_setting[:role_id]
      end
      role_question.privacy_settings.build(setting_type: new_privacy_setting[:setting_type], role_id: new_privacy_setting[:role_id]) if existing_privacy_setting.blank?
    end
  end

  def restricted_privacy_setting_options(program)
    RoleQuestionPrivacySetting.restricted_privacy_setting_options_for(program).collect do |options|
      options[:privacy_setting]
    end
  end

  def pre_process_privacy_attrs(attrs)
    arr = []
    to_integer_keys_and_values(attrs).each do |type, settings|
      if type == RoleQuestion::PRIVACY_SETTING::RESTRICTED
        settings.each do |setting_type, values|
          if setting_type == RoleQuestionPrivacySetting::SettingType::ROLE
            values.keys.each do |role_id|
              arr << [type, {setting_type: setting_type, role_id: role_id}]
            end
          else
            arr << [type, {setting_type: setting_type, role_id: nil}]
          end
        end
      else
        arr << [type]
      end
    end
    arr
  end

  # Does the following conversion
  # {"1" => "2", "3" => {"4" => "5", "6" => "7"}}  ====> {1 => 2, 3 => {4 => 5, 6 => 7}}
  def to_integer_keys_and_values(hash)
    hash = hash.is_a?(ActionController::Parameters) ? hash.permit!.to_h : hash
    keys_values = hash.map do |k,v|
      if(v.is_a? Hash)
        new_value = to_integer_keys_and_values(v)
      else
        new_value = v.to_i
      end
      [k.to_i, new_value]
    end
    Hash[keys_values]
  end
end