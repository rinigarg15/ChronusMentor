module LanguagesHelper
  # Set the I18n.locale either from member or cookie
  # TODO Test for helper
  def set_locale_from_cookie_or_member
    if wob_member
      locale = Language.for_member(wob_member, @current_program)
      I18n.locale = locale
      # We also set the locale in the cookie, because we need to retain the locale, even when the user has logged out of the site.
      store_locale_to_cookie(locale)
    else
      I18n.locale = current_locale
    end
  end

  # Returns the current locale either from 
  def current_locale(options = {from_non_org: false})
    if wob_member
      Language.for_member(wob_member, @current_program)
    else
      new_locale = cookies[:current_locale]
      (valid_locale?(new_locale, super_console?, wob_member, program_context, from_non_org: options[:from_non_org]) ? new_locale : I18n.default_locale.to_s).to_sym
    end
    
  end

  def store_locale_to_cookie(value, options = {from_non_org: false})
    if valid_locale?(value, super_console?, wob_member, program_context, from_non_org: options[:from_non_org])
     cookies[:current_locale] = value.to_s
    else
      cookies[:current_locale] = I18n.default_locale.to_s
    end
  end

  def store_locale_to_member(value)
    if valid_locale?(value, super_console?, wob_member, program_context)
     if wob_member
       Language.set_for_member(wob_member, value)
     end
    end
  end

  def get_available_languages(from_non_org=false)
    current_language = Language.find_by(language_name: current_locale({from_non_org: from_non_org}).to_s)
    english_language = Language.for_english
    current_language = english_language if valid_locale?(current_language, super_console?, wob_member, program_context, from_non_org: false)
    other_languages  = Language.supported_for(super_console?, wob_member, program_context, {from_non_org: from_non_org})

    return_value = []
    return_value << build_language_for_view(current_language, @current_organization, from_non_org: from_non_org) if current_language
    return_value << build_language_for_view(english_language, @current_organization, from_non_org: from_non_org)

    other_languages.each do |language|
      return_value << build_language_for_view(language, @current_organization, from_non_org: from_non_org)
    end
    return return_value.uniq
  end

  private
  def valid_locale?(value, is_super_console, wob_member, abstract_program, options = {from_non_org: false})
    return false if value.nil?
    Language.valid_locale?(value, is_super_console, wob_member, abstract_program, from_non_org: options[:from_non_org])
  end

  def build_language_for_view(language, organization, options = {from_non_org: false})
    org_language = OrganizationLanguage.unscoped.find_by(organization_id: organization.id, language_id: language.id) if !options[:from_non_org]
    return {
      :title_for_display => (language.default? || options[:from_non_org] || !org_language.present?) ? language.to_display : org_language.to_display,
      :language_name     => language.language_name
    }
  end


end