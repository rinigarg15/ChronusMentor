require_relative './../../../test_helper'

class Mailer::TemplateObserverTest < ActiveSupport::TestCase
  def test_content_not_copied_to_default_locale
    mt = Mailer::Template.first
    default_locale_translation = mt.translations.find_or_create_by(locale: I18n.default_locale)
    default_locale_translation.update_attributes(source: nil, subject: nil)
    GlobalizationUtils.run_in_locale(:'fr-CA') do
      mt.source = "French source"
      mt.subject = "French subject"
      mt.save!
    end
    assert_nil default_locale_translation.reload.source
    assert_nil default_locale_translation.subject
  end

  def test_default_content_created
    uid = 's9kiyrsk'
    mt = Mailer::Template.find_by(uid: uid)
    mt.translations.find_by(locale: I18n.default_locale).try(:destroy)
    email_hash = ChronusActionMailer::Base.get_descendant(uid).mailer_attributes
    GlobalizationUtils.run_in_locale(:'fr-CA') do
      mt.update_with_translations({ source: "French source", subject: "French subject" }, [I18n.default_locale], email_hash)
    end
    assert_equal email_hash[:subject].call, mt.subject
    assert_equal ChronusActionMailer::Base.default_email_content_from_path(email_hash[:view_path]), mt.source
  end
end