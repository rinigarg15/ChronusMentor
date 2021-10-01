module LocalizableContent
  ANNOUNCEMENT                        = 'announcement'
  CAMPAIGN                            = 'campaign'
  CONTACT_ADMIN                       = 'contact_admin' #not globalized as of now
  MENTORING_CONNECTION_PROFILE_FIELD  = 'mentoring_connection_profile_field'
  MENTORING_MODEL                     = 'mentoring_model'
  PROGRAM_EVENTS                      = 'program_events'
  PROGRAM_SETTINGS                    = 'program_settings'
  OVERVIEW_PAGES                      = 'overview_pages'
  RESOURCES                           = 'resources'
  SURVEY                              = 'survey'
  USER_PROFILE                        = 'user_profile'
  INSTRUCTION                         = 'instruction'
  PROGRAM_ASSET                       = 'program_asset'
  PROFILE_QUESTION                    = 'profile_question'
  SURVEY_QUESTION                     = 'survey_question'

  def self.attributes_for_model(options = {})
    hash = { #here order of attributes matters, here first attribute's presence is compulsory hence while displaying directly using that, if not so handle row header accordingly
      Announcement => [:title, :body],
      CampaignManagement::AbstractCampaign => [:title],
      CampaignManagement::UserCampaign => [:title],
      CampaignManagement::ProgramInvitationCampaign => [:title],
      CampaignManagement::SurveyCampaign => [:title],
      ContactAdminSetting => [:label_name, :content],
      Connection::Question => [:question_text, :help_text],
      CustomizedTerm => [:term, :pluralized_term, :articleized_term],
      EngagementSurvey => [:name],
      GroupClosureReason => [:reason],
      Mailer::Template => [:subject, :source],
      MeetingFeedbackSurvey => [:name],
      MentoringModel => [:title, :description, :forum_help_text],
      MentoringModel::TaskTemplate => [:title, :description],
      MentoringModel::GoalTemplate => [:title, :description],
      MentoringModel::MilestoneTemplate => [:title, :description],
      MentoringModel::FacilitationTemplate => [:subject, :message],
      AbstractInstruction => [:content],
      MentorRequest::Instruction => [:content],
      MembershipRequest::Instruction => [:content],
      Organization => [:agreement, :privacy_policy, :browser_warning],
      Page => [:title, :content],
      ProfileQuestion => [:question_text, :help_text],
      QuestionChoice => [:text],
      AbstractProgram => [:name, :description],
      ProgramAsset => [:logo_file_name, :banner_file_name],
      ProgramEvent => [:title, :description],
      Survey => [:name],
      ProgramSurvey => [:name],
      Resource => [:title, :content],
      Role => [:name, :description, :eligibility_message],
      Section => [:title, :description],
      SurveyQuestion => [:question_text, :help_text]
    }
    hash[Program] = hash[AbstractProgram]
    hash[CareerDev::Portal] = hash[AbstractProgram]
    hash[Program] = [:zero_match_score_message] if !options[:category].nil? && options[:category] == LocalizableContent::PROGRAM_SETTINGS && !options[:tab].nil? && options[:tab] == ProgramsController::SettingsTabs::MATCHING
    return hash
  end

  def self.expands_to
    {
      ANNOUNCEMENT => :title,
      CAMPAIGN => :title,
      MENTORING_MODEL => :title,
      PROGRAM_EVENTS => :title,
      PROGRAM_SETTINGS => :heading,
      OVERVIEW_PAGES => :title,
      RESOURCES => :title,
      SURVEY => :name,
      USER_PROFILE => :title,
      INSTRUCTION => :type,
      PROFILE_QUESTION => :question_text,
      SURVEY_QUESTION => :question_text,
      MENTORING_CONNECTION_PROFILE_FIELD => :question_text
    }
  end

  def self.content_for_heading(category, element, heading)
    return "program_settings_strings.header.#{LocalizableContent::organization_attributes_translations[heading.to_sym]}".translate if element.is_a?(Organization)
    case category
    when ANNOUNCEMENT
      element[heading].presence || "feature.announcements.label.no_title".translate
    when INSTRUCTION
      element.type.constantize
    else
      element[heading]
    end
  end

  def self.relations
    {
      ANNOUNCEMENT => [:announcements],
      CAMPAIGN => {:abstract_campaigns => [:email_templates]},
      INSTRUCTION => [:abstract_instructions],
      CONTACT_ADMIN => [:contact_admin_setting],
      MENTORING_CONNECTION_PROFILE_FIELD => {:connection_questions => [:default_question_choices]},
      MENTORING_MODEL => {:mentoring_models => [:mentoring_model_goal_templates_without_handle_hybrid_templates, :mentoring_model_milestone_templates_without_handle_hybrid_templates, :mentoring_model_task_templates_without_handle_hybrid_templates, :mentoring_model_facilitation_templates_without_handle_hybrid_templates]},
      PROGRAM_ASSET => [:program_asset],
      PROGRAM_EVENTS => [:program_events],
      PROGRAM_SETTINGS => [:translation_settings_sub_categories],
      OVERVIEW_PAGES => [:pages],
      RESOURCES => [:resources],
      SURVEY => [:visible_surveys],
      SURVEY_QUESTION => {:survey_questions => [:default_question_choices]},
      USER_PROFILE => [:sections],
      PROFILE_QUESTION => {:profile_questions => [:default_question_choices]}
    }
  end

  def self.tab_relations
    {
      ProgramsController::SettingsTabs::TERMINOLOGY => :get_terms_for_view,
      ProgramsController::SettingsTabs::MEMBERSHIP => :roles_without_admin_role,
      ProgramsController::SettingsTabs::CONNECTION => :permitted_closure_reasons
    }
  end

  def self.eager_load_association
    {
      :announcements => [:translations],
      :abstract_campaigns => [:translations, :email_templates => :translations],
      :connection_questions => [{default_question_choices: :translations}, :translations],
      :mentoring_models => [:translations, :mentoring_model_goal_templates => [:translations], :mentoring_model_milestone_templates => [:translations], :mentoring_model_task_templates => [:translations], :mentoring_model_facilitation_templates => [:translations]],
      :program_events => [:translations],
      :goal_templates => [:translations],
      :pages => [:translations],
      :resources => [:translations],
      :visible_surveys => [:translations],
      :survey_questions => [{default_question_choices: :translations}, :translations],
      :sections => [:translations],
      :profile_questions => [{default_question_choices: :translations}, :translations],
      :get_terms_for_view => [:translations],
      :roles_without_admin_role => [:translations],
      :permitted_closure_reasons => [:translations],
      :abstract_instructions => [:translations]
    }
  end

  def self.cannot_include_translation
    [:contact_admin_setting, :translation_settings_sub_categories]
  end

  def self.heading_help
    {
      MentoringModel::TaskTemplate => 'task_template',
      MentoringModel::GoalTemplate => 'goal_template',
      MentoringModel::MilestoneTemplate => 'milestone_template',
      MentoringModel::FacilitationTemplate => 'facilitatoin_message_template'
    }
  end

  def self.attribute_for_heading
    {
      Role => [:name]
    }
  end

  def self.feature_dependency
    {
      MENTORING_CONNECTION_PROFILE_FIELD => FeatureName::CONNECTION_PROFILE,
      MENTORING_MODEL => FeatureName::MENTORING_CONNECTIONS_V2,
      PROGRAM_EVENTS => FeatureName::PROGRAM_EVENTS,
      RESOURCES => FeatureName::RESOURCES
    }
  end

  def self.get_editable_condition
    {
      ProgramSurvey => [:overdue?]
    }
  end

  # Organization T&C, Privacy Policy are checked for presence if a flag display_custom_terms_only is present. This case is not handled
  def self.ckeditor_type_required_content
    {
      Resource => ["content"],
      Mailer::Template => ["source"],
      MentoringModel::FacilitationTemplate => ["message"]
    }
  end

  def self.ckeditor_type
    {
      Announcement => {:body => :default},
      Organization => {:agreement => :default, :privacy_policy => :default, :browser_warning => :default},
      Mailer::Template => {:source => :default}, #in case of campaign this has to be dropdownckoptions
      MentoringModel::TaskTemplate => {:description => :minimal},
      MentoringModel::FacilitationTemplate => {:message => :dropdown},
      Page => {:content => :full},
      ProfileQuestion => {:help_text => :minimal},
      ProgramEvent => {:description => :full},
      Resource => {:content => :full},
      Role => {:description => :minimal}
    }
  end

  def self.dependent_attributes
    {
      CustomizedTerm => {
        # Here key is an attribute A and value is an array of depenedent attributes dependent on A. The element of array will be in this format [dependent_attribute, function_to_compute_the_attribute_value]
        :term => [[:term_downcase, :to_downcase]], 
        :pluralized_term => [[:pluralized_term_downcase, :to_downcase]], 
        :articleized_term => [[:articleized_term_downcase, :to_downcase]]
      }
    }
  end

  def self.ckeditor_tags
    {
      preview: %w[a address blockquote br caption div em embed h1 h2 h3 h4 h5 h6 hr li object ol p param pre s span strong sub sup b i u ul style],
      full_display: %w[a address blockquote br caption div em embed h1 h2 h3 h4 h5 h6 hr iframe img li object ol p param pre s span strong sub sup table tbody td tfoot th thead tr b i u ul style]
    } 
  end

  def self.org_level
    [OVERVIEW_PAGES, PROGRAM_SETTINGS, RESOURCES, USER_PROFILE, PROGRAM_ASSET, PROFILE_QUESTION]
  end

  def self.program_level
    [ANNOUNCEMENT, CAMPAIGN, INSTRUCTION, CONTACT_ADMIN, MENTORING_MODEL, MENTORING_CONNECTION_PROFILE_FIELD, PROGRAM_EVENTS, OVERVIEW_PAGES, PROGRAM_SETTINGS, RESOURCES, SURVEY, SURVEY_QUESTION, PROGRAM_ASSET]
  end

  def self.all
    [ANNOUNCEMENT, CAMPAIGN, INSTRUCTION, CONTACT_ADMIN, MENTORING_MODEL, MENTORING_CONNECTION_PROFILE_FIELD, PROGRAM_EVENTS, OVERVIEW_PAGES, PROGRAM_SETTINGS, RESOURCES, SURVEY, USER_PROFILE, PROGRAM_ASSET, PROFILE_QUESTION, SURVEY_QUESTION]
  end

  def org_category?(category)
    LocalizableContent.org_level.include?(category)
  end

  def prog_category?(category)
    LocalizableContent.program_level.include?(category)
  end

  def self.is_program_asset?(category)
    category == PROGRAM_ASSET
  end

  def self.organization_attributes_translations
    {
      :agreement => "tnc",
      :privacy_policy => "privacy_policy",
      :browser_warning => "browser_warning"
    }
  end
end