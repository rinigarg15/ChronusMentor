# ProfileQuestion::Importer
#   imports profiles from CSV for given program
#   headers:
#   - Section Name
#   - Section Description
#   - Field Name
#   - Field Type
#   - Allow Multiple Responses
#   - Options
#   - Options Count
#   - Allow to Specify Different Answer
#   - Field Description
#   - Include for Mentor|Mentee
#   - Include in Profile
#   - Include in Membership Form
#   - Visibility
#   - Editable by Admin Only
#   - Mandatory
#   - Show in Listing
#   - Available for Search

class ProfileQuestion::Importer
  # Error object
  class Error
    attr_reader :line, :errors
    def initialize(row, errors)
      @line, @errors = row, errors
    end
  end
  # errors indicator
  def self.errors
    @errors ||= []
  end
  # error message
  def self.error_messages
    @errors.map do |e|
      if e.line.blank?
        %{Parsing error: #{e.errors.full_messages.join(", ")}}
      else
        %{Error at line #{e.line}: #{e.errors.full_messages.join(", ")}}
      end
    end
  end
  def self.reset_errors
    @errors = []
  end
  # default name for section
  def self.default_section_name
    "Basic Information"
  end
  # build objects from hash generated by 'build_attributes'
  def self.build_from_hash(data, organization, program = nil)
    # get first available program
    program ||= organization.programs.ordered.first
    # build objects
    program.build_default_roles
    data.each do |s|
      section = organization.sections.build(s[:attributes].merge(organization: organization))
      s[:profile_questions].each do |q|
        profile_question = section.profile_questions.build(q[:attributes].merge(organization: organization, section: section))
        q[:question_choices].each do |qc|
          profile_question.question_choices.build(qc[:attributes].merge(ref_obj: profile_question))
        end
        q[:role_questions].each do |r|
          role = program.get_role(r[:role_name]) || program.build_role(r[:role_name])
          role_question = profile_question.role_questions.build(r[:attributes].merge(role: role, profile_question: profile_question))
          (r[:privacy_settings] || []).each do |ps|
            role = program.get_role(ps[:role_name])
            privacy_setting = role_question.privacy_settings.build(ps[:attributes].merge(role_question: role_question))
            privacy_setting.role = role if privacy_setting.setting_type == RoleQuestionPrivacySetting::SettingType::ROLE
          end
        end
      end
    end
  end
  # import csv from the stream
  def self.import_csv(stream, organization, program = nil)
    reset_errors
    section_position = 1
    row_number = 2
    location_added = false
    # get first available program if not given
    program ||= organization.programs.ordered.first
    # default section and questions
    sections = {
      default_section_name => build_default_section(organization),
    }
    question_position = build_default_questions(organization, program, sections[default_section_name])
    # parse CSV
    csv_options = {
      col_sep:    ",",
      quote_char: '"',
      encoding:   "utf-8",
      headers:    true,
    }
    begin
      CSV.parse(File.read(stream.path, encoding: UTF8_BOM_ENCODING), csv_options) do |row|
        unless expected_headers == row.headers
          missing_headers = %{missing headers - #{(expected_headers - row.headers).join(", ")}}
          unexpected_headers = %{invalid headers - #{(row.headers - expected_headers).join(", ")}}
          err = ActiveModel::Errors.new(self)
          err.add(:base, [missing_headers, unexpected_headers].join(", "))
          @errors << Error.new(1, err)
          break
        end
        # select/build section
        section_name = row["Section Name"]
        section_name = default_section_name if section_name.blank?
        unless sections.has_key?(section_name)
          # build section
          section_description = row["Section Description"]
          section_params = {
            title:         section_name,
            description:   section_description,
            position:      section_position += 1,
            default_field: (section_name == default_section_name),
            organization:  organization,
          }
          sections[section_name] = organization.sections.build(section_params)
        end
        section = sections[section_name]
        # build profile question for this section
        question_params = {
          section:            section,
          organization:       organization,
          question_text:      row["Field Name"],
          question_type:      get_question_type(row),
          options_count:      row["Options Count"].to_i,
          allow_other_option: yesno_to_bool(row["Allow to Specify Different Answer"]),
          help_text:          row["Field Description"].to_s,
          position:           question_position += 1,
        }
        profile_question = section.profile_questions.build(question_params)

        row["Options"].to_s.split_by_comma.each_with_index do |option, index|
          profile_question.question_choices.build(text: option, position: index + 1, ref_obj: profile_question)
        end

        program.build_default_roles
        # validate if OK
        location_already_exists = location_added && (ProfileQuestion::Type::LOCATION == profile_question.question_type)
        if !location_already_exists && ProfileQuestion::Type::EMAIL != profile_question.question_type && profile_question.valid?
          location_added ||= ProfileQuestion::Type::LOCATION == profile_question.question_type
          # for both mentor and mentee roles
          [ [RoleConstants::MENTOR_NAME,  0],
            [RoleConstants::STUDENT_NAME, 1],
          ].each do |role_name, index|
            # check if we need role_question
            need_role_question = yesno_to_bool(value_by_index(row["Include for Mentor|Mentee"], index))
            # build role_questions
            if need_role_question
              role = program.get_role(role_name) || program.build_role(role_name)
              private_value, privacy_setting_options = compute_private_value(program, value_by_index(row["Visibility"], index))
              privacy_setting_options ||= []
              # determine availability
              role_question_params = {
                role:                role,
                profile_question:    profile_question,
                required:            yesno_to_bool(value_by_index(row["Mandatory"], index)),
                private:             private_value,
                filterable:          yesno_to_bool(value_by_index(row["Available for Search"], index)),
                in_summary:          yesno_to_bool(value_by_index(row["Show in Listing"], index)),
                available_for:       get_available_for(row, index),
                admin_only_editable: yesno_to_bool(value_by_index(row["Editable by Admin Only"], index)),
              }
              role_question = profile_question.role_questions.build(correct_role_question_params(role_question_params))
              privacy_setting_options.each do |privacy_setting_params|
                role_question.privacy_settings.build(privacy_setting_params)
              end
            end
          end
        else
          if location_already_exists
            err = ActiveModel::Errors.new(profile_question)
            err.add(:base, "organization should has one 'location' question")
            @errors << Error.new(row_number, err)
          elsif ProfileQuestion::Type::EMAIL == profile_question.question_type
            err = ActiveModel::Errors.new(profile_question)
            err.add(:question_type, "can't be email")
            @errors << Error.new(row_number, err)
          else
            @errors << Error.new(row_number, profile_question.errors)
          end
        end
        # increment row #
        row_number += 1
      end
    rescue Exception => e
      err = ActiveModel::Errors.new(self)
      err.add(:base, e.message)
      @errors << Error.new(nil, err)
    end
    @errors.empty? && build_attributes(organization.sections)
  end

protected
  def self.expected_headers
    [
      "Section Name",
      "Section Description",
      "Field Name",
      "Field Type",
      "Allow Multiple Responses",
      "Options",
      "Options Count",
      "Allow to Specify Different Answer",
      "Field Description",
      "Include for Mentor|Mentee",
      "Include in Profile",
      "Include in Membership Form",
      "Visibility",
      "Editable by Admin Only",
      "Mandatory",
      "Show in Listing",
      "Available for Search",
    ]
  end

  def self.build_attributes(organization_sections)
    sections = []
    organization_sections.each do |s|
      profile_questions = []
      s.profile_questions.each do |q|
        role_questions = []
        q.role_questions.each do |r|
          privacy_settings = []
          r.privacy_settings.each do |ps|
            privacy_settings << {
              role_name: ps.role.try(:name),
              attributes: ps.attributes
            }
          end
          role_questions << {
            role_name: r.role.name,
            attributes: r.attributes,
            privacy_settings: privacy_settings
          }
        end
        question_choices = q.question_choices.collect do |qc|
          {attributes: qc.populate_question_choice_attributes} 
        end
        profile_questions << {
          attributes: q.populate_profile_question_attributes,
          role_questions: role_questions,
          question_choices: question_choices
        }
      end
      sections << {
        attributes: s.populate_section_attributes,
        profile_questions: profile_questions,
      }
    end
    sections
  end

  def self.build_default_section(organization)
    organization.sections.build({
      title:         default_section_name,
      description:   "",
      position:      1,
      default_field: true,
      organization:  organization,
    })
  end

  def self.build_role_questions(program, question, params)
    # for both mentor and mentee roles
    [ [RoleConstants::MENTOR_NAME,  0],
      [RoleConstants::STUDENT_NAME, 1],
    ].each do |role_name, index|
      # build role_questions
      role = program.get_role(role_name) || program.build_role(role_name)
      # determine availability
      default_role_params = {
        role:                role,
        profile_question:    question,
        required:            true,
        available_for:       RoleQuestion::AVAILABLE_FOR::BOTH,
        admin_only_editable: false,
      }
      privacy_setting_params = params.delete(:privacy_setting_params) || []
      role_question = question.role_questions.build(correct_role_question_params(default_role_params.merge(params)))
      privacy_setting_params.each do |privacy_setting|
        role_question.privacy_settings.build(privacy_setting)
      end
    end
  end

  def self.build_question(organization, program, section, params)
    default_question_params = {
      section:            section,
      organization:       organization,
      options_count:      0,
      allow_other_option: false,
      help_text:          "",
    }
    role_question_params = params.delete(:role_question_params)
    question = section.profile_questions.build(default_question_params.merge(params))
    build_role_questions(program, question, role_question_params)
    question
  end

  def self.build_name_question(organization, program, section)
    # build Name question
    name_question_params = {
      question_text: "Name",
      question_type: ProfileQuestion::Type::NAME,
      position:      1,
      role_question_params: {
        filterable:  true,
        in_summary:  true,
        private:     RoleQuestion::PRIVACY_SETTING::ALL,
      }
    }
    build_question(organization, program, section, name_question_params)
  end

  def self.build_email_question(organization, program, section)
    # build Email question
    email_question_params = {
      question_text: "Email",
      question_type: ProfileQuestion::Type::EMAIL,
      position:      2,
      role_question_params: {
        filterable:  false,
        in_summary:  false,
        private:     RoleQuestion::PRIVACY_SETTING::RESTRICTED,
        privacy_setting_params: [
          { setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS }
        ]
      }
    }
    build_question(organization, program, section, email_question_params)
  end

  def self.build_default_questions(organization, program, section)
    [ build_name_question(organization, program, section),
      build_email_question(organization, program, section),
    ].size
  end

  def self.get_question_type(row)
    question_type = string_to_question_type[row["Field Type"]]
    if yesno_to_bool(row["Allow Multiple Responses"]) && PROFILE_MERGED_QUESTIONS.has_value?(question_type)
      question_type = PROFILE_MERGED_QUESTIONS.invert[question_type]
    end
    question_type
  end

  def self.value_by_index(value, index)
    values = value.split("|")
    1 == values.size ? value : values[index]
  end

  def self.correct_role_question_params(params)
    if params[:admin_only_editable] || RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE == params[:private]
      params[:admin_only_editable] = true
      params[:available_for] = RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS
      params[:required] = false
    end
    params
  end


  def self.get_available_for(row, index)
    profile = yesno_to_bool(value_by_index(row["Include in Profile"], index))
    membership_form = yesno_to_bool(value_by_index(row["Include in Membership Form"], index))
    if profile && membership_form
      RoleQuestion::AVAILABLE_FOR::BOTH
    elsif profile
      RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS
    elsif membership_form
      RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS
    end
  end

  def self.yesno_to_bool(yes_no)
    { "yes" => true, "no" => false }[yes_no] || false
  end

  def self.string_to_question_type
    {
      "string"                => ProfileQuestion::Type::STRING,
      "text"                  => ProfileQuestion::Type::TEXT,
      "single_choice"         => ProfileQuestion::Type::SINGLE_CHOICE,
      "multi_choice"          => ProfileQuestion::Type::MULTI_CHOICE,
      # "rating_scale"          => ProfileQuestion::Type::RATING_SCALE,
      "file"                  => ProfileQuestion::Type::FILE,
      "multi_string"          => ProfileQuestion::Type::MULTI_STRING,
      "ordered_single_choice" => ProfileQuestion::Type::SINGLE_CHOICE,
      "location"              => ProfileQuestion::Type::LOCATION,
      "experience"            => ProfileQuestion::Type::EXPERIENCE,
      "multi_experience"      => ProfileQuestion::Type::MULTI_EXPERIENCE,
      "education"             => ProfileQuestion::Type::EDUCATION,
      "multi_education"       => ProfileQuestion::Type::MULTI_EDUCATION,
      "publication"           => ProfileQuestion::Type::PUBLICATION,
      "multi_publication"     => ProfileQuestion::Type::MULTI_PUBLICATION,
      "manager"               => ProfileQuestion::Type::MANAGER,
      "email"                 => ProfileQuestion::Type::EMAIL,
      "skype_id"              => ProfileQuestion::Type::SKYPE_ID,
      "ordered_options"       => ProfileQuestion::Type::ORDERED_OPTIONS,
      "date"                  => ProfileQuestion::Type::DATE
    }
  end

  # Possible values for Visibility column can be one or more of the following.
  # "everyone"              -> Shown to all
  # "administrators"        -> Shown only to administrators
  # "user"                  -> Shown to administrators and users only
  # "user_and_his_members"  -> Shown to administrators, users and the user's connected members only
  # "user_and_mentors"      -> Shown to administrators, users and all the mentors
  # "user_and_mentees"      -> Shown to administrators, users and all the mentees

  # If more than one value if provided, each of those values will be accomodated.
  # For ex: user_and_mentors, user_and_mentees -> Shown to administrators, users and all the mentors and mentees

  module VisibilityOptions
    ALL        = "everyone"
    USER_ONLY  = "user"
    CONNECTED_MEMBERS = "his_members"

    # This regex is used to match the values: user_and_his_members, user_and_mentors, user_and_mentees, user_and_employees etc.
    RESTRICTED = /user_and_(.+)/
  end

  def self.compute_private_value(program, private_values)
    private_values = private_values.split(",").collect!(&:strip)
    return RoleQuestion::PRIVACY_SETTING::ALL if private_values.include?(VisibilityOptions::ALL)

    if (restricted_values = private_values.grep(VisibilityOptions::RESTRICTED)).present?
      restricted_values.collect! { |value| value[VisibilityOptions::RESTRICTED, 1] }
      return RoleQuestion::PRIVACY_SETTING::RESTRICTED, compute_restricted_privacy_settings(program, restricted_values)
    elsif private_values.include?(VisibilityOptions::USER_ONLY)
      return RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
    else
      return RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE
    end
  end

  def self.compute_restricted_privacy_settings(program, restricted_values)
    restricted_values.collect do |value|
      if value == VisibilityOptions::CONNECTED_MEMBERS
        {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS}
      else
        role_name = value.singularize
        role_name = RoleConstants::ROLE_DISPLAY_NAME_MAPPING.invert[role_name].presence || role_name
        role = program.get_role(role_name)
        {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role: role}
      end
    end
  end
end
