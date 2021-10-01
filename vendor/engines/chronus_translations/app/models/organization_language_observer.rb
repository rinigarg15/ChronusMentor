class OrganizationLanguageObserver < ActiveRecord::Observer

  def before_create(organization_language)
    organization_language.language_name = organization_language.language.language_name
  end

  def after_save(organization_language)
    organization_language.handle_enabled_program_languages
    organization_language.es_reindex
    return if organization_language.disabled?

    Mailer::Template.add_translation_for_existing_mailer_templates(organization_language.organization, organization_language.language)
    Mailer::Widget.add_translation_for_existing_mailer_widgets(organization_language.organization, organization_language.language)
    MentorRequest::Instruction.populate_content_for_language(organization_language.organization, organization_language.language.language_name)
    Program.add_translation_for_zero_match_score_message_in_locales(organization_language.organization, organization_language.language.language_name)
    Role.populate_content_for_language(organization_language.organization, organization_language.language.language_name)
  end
end