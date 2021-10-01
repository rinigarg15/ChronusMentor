class OrganizationObserver < ActiveRecord::Observer

  def after_create(organization)
    organization.populate_default_customized_terms
    organization.create_default_roles
    create_about_pages(organization) unless organization.created_for_sales_demo
    create_default_questions(organization) if organization.sections.blank? && !organization.creating_using_solution_pack
    create_default_resources(organization) unless organization.created_for_sales_demo
    organization.make_subscription_changes
    Organization.delay.create_default_admin_views(organization.id) unless organization.created_for_sales_demo
    organization.create_security_setting!(linkedin_token: APP_CONFIG[:linkedin_token], linkedin_secret: APP_CONFIG[:linkedin_secret])
    organization.create_auth_config_setting!
    organization.create_default_auth_configs(organization.created_for_sales_demo.present?)
    organization.create_and_populate_default_three_sixty_settings!
    organization.create_competency_and_questions!
    add_browser_warning_content_for_all_locales(organization)
  end

  def before_create(organization)
    bw = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/default_browser_warning_content.yml")).result)
    browser_warning_content = bw.inject{|hash,val| (hash ||= {}).merge!(val)}
    organization.browser_warning = browser_warning_content[I18n.default_locale.to_s]
    organization.active_theme = Theme.global.default.first
  end

  private

  def add_browser_warning_content_for_all_locales(organization)
    bw = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/default_browser_warning_content.yml")).result)
    browser_warning_content = bw.inject{|hash,val| (hash ||= {}).merge!(val)}
    locales = organization.languages.collect(&:language_name).collect(&:to_s)
    locales << I18n.default_locale.to_s
    locales.each do |locale|
      translation = organization.translation_for(locale) || organization.translations.build(:locale => locale)
      translation[:browser_warning] = browser_warning_content[locale]
      translation.save!
    end
  end

  # Create the "About organization" pages for the given organization
  def create_about_pages(organization)
    organization.pages.create(YAML::load(ERB.new(IO.read("#{Rails.root}/config/default_pages_content.yml")).result(binding)))
  end

  def create_default_questions(organization)
    profile_question_data = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/default_profile_questions.yml")).result)
    default_questions = profile_question_data["profile_questions"]
    default_sections = profile_question_data["sections"]

    default_sections.each do |sec_data|
      organization.sections.create!({:organization => organization}.merge(sec_data))
    end

    default_questions.each do |sec_ques_data|
      sec_ques_data.each do |key, sec_data|
        sec_data.each do |ques_data|
          choices = ques_data.delete("question_choices")
          ques = organization.profile_questions.build(ques_data)
          choices.each_with_index do |choice, index|
            ques.question_choices.build(text: choice, position: index + 1, ref_obj: ques)
          end if choices.present?
          ques.section = organization.sections.select{|s| s.title.to_html_id == key}.first
          ques.save!
        end
      end
    end
  end

  def create_default_resources(organization)
    resources = YAML::load(ERB.new(IO.read("#{Rails.root}/config/default_resources.yml")).result(binding))
    resources.each do |default_resource|
      resource = organization.resources.create!({:title => default_resource['title'], :content => default_resource['content'], :default => true})
    end
  end
end
