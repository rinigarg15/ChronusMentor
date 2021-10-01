namespace :mailer_template do
  task :copy_existing_default_content => :environment do
    mailer_template_klasses = ChronusActionMailer::Base.get_descendants.reject{|mail| mail.mailer_attributes[:donot_list] || mail.mailer_attributes[:disable_customization]}
    @default_content = get_default_mail_content(mailer_template_klasses)
    Organization.active.includes(:languages, :mailer_templates, :programs => [:mailer_templates]).each do |org|
      copy_for_org(org, mailer_template_klasses)
    end
  end
end

private

def get_default_mail_content(mailer_template_klasses)
  default_content = {}
  mailer_template_klasses.each do |klass|
    default_content[klass.mailer_attributes[:uid]] = get_default_value_for_all_languages(klass)
  end
  return default_content
end

def get_default_value_for_all_languages(klass)
  content = {}
  content[I18n.default_locale] = get_default_value(klass)
  languages.each do |lang|
    content[lang.language_name.to_sym] = get_default_value(klass, lang.language_name)
  end
  return content
end

def get_default_value(klass, locale=nil)
  content = {}
  I18n.locale = locale if locale.present?
  content[:subject] = klass.mailer_attributes[:subject].call
  content[:source] = klass.default_email_content_from_path(klass.mailer_attributes[:view_path])
  I18n.locale = I18n.default_locale
  return content
end

def languages
  @languages ||= Language.all
end

def copied_content(mt)
  if !mt.subject.present? && !mt.source.present?
    Mailer::Template::CopiedContent::BOTH
  elsif !mt.subject.present?
    Mailer::Template::CopiedContent::SUBJECT
  elsif !mt.source.present?
    Mailer::Template::CopiedContent::SOURCE
  end
end

def copy_content_for_mail(klass, org, org_languages)
  mt = copy_content_for_default_lang(klass, org)
  org_languages.each do |lang|
    copy_content_for_other_lang(klass, lang.language_name.to_sym, mt)
  end
end

def copy_content_for_default_lang(klass, org)
  mt = org.mailer_templates.find{|m| m.uid == klass.mailer_attributes[:uid]} || org.mailer_templates.new(copied_content: Mailer::Template::CopiedContent::BOTH, uid: klass.mailer_attributes[:uid])
  mt.copied_content ||= copied_content(mt)
  mt.subject = @default_content[klass.mailer_attributes[:uid]][I18n.default_locale][:subject] unless mt.subject.present?
  mt.source = @default_content[klass.mailer_attributes[:uid]][I18n.default_locale][:source] unless mt.source.present?
  mt.save! if mt.copied_content
  return mt
end

def copy_content_for_other_lang(klass, locale, mt)
  mtt = mt.translations.find{|trans| trans.locale == locale} || mt.translations.new(locale: locale)
  mtt.subject = @default_content[klass.mailer_attributes[:uid]][locale][:subject] unless mtt.subject.present?
  mtt.source = @default_content[klass.mailer_attributes[:uid]][locale][:source] unless mtt.source.present?
  mtt.save!
end

def copy_for_org(org, mailer_template_klasses)
  org_languages = org.languages
  mailer_template_klasses.each do |klass|
    next unless klass.mailer_attributes[:level] == EmailCustomization::Level::ORGANIZATION
    copy_content_for_mail(klass, org, org_languages)
  end

  org.programs.each do |prog|
    mailer_template_klasses.each do |klass|
      next unless klass.mailer_attributes[:level] == EmailCustomization::Level::PROGRAM
      copy_content_for_mail(klass, prog, org_languages)
    end
  end
end