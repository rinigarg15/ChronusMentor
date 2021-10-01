require_relative "./../../../test_helper.rb"

class MailerExtensions::SetupTest < ActiveSupport::TestCase
  include MailerExtensions::Setup

  def test_set_host_name_for_urls
    program = programs(:albers)
    organization = program.organization

    execute_preserving_url_options do
      set_host_name_for_urls(nil)
      assert_equal_hash( {
        host: DEFAULT_HOST_NAME,
        protocol: "https"
      }, ActionMailer::Base.default_url_options)
    end

    execute_preserving_url_options do
      set_host_name_for_urls(organization)
      assert_equal_hash( {
        protocol: "https",
        host: organization.domain,
      }, ActionMailer::Base.default_url_options)
    end

    execute_preserving_url_options do
      set_host_name_for_urls(organization, program)
      assert_equal_hash( {
        protocol: "https",
        host: organization.domain,
        root: program.root
      }, ActionMailer::Base.default_url_options)
    end
  end

  def test_set_host_name_for_urls_handles_set_locale_and_root
    program = programs(:albers)
    organization = program.organization

    execute_preserving_url_options do
      ActionMailer::Base.default_url_options[:set_locale] = :de
      ActionMailer::Base.default_url_options[:root] = program.root
      set_host_name_for_urls(organization)
      assert_equal_hash( {
        protocol: "https",
        host: organization.domain
      }, ActionMailer::Base.default_url_options)
    end

    execute_preserving_url_options do
      @set_locale = :de
      ActionMailer::Base.default_url_options[:set_locale] = @set_locale
      ActionMailer::Base.default_url_options[:root] = program.root
      set_host_name_for_urls(organization, program)
      assert_equal_hash( {
        protocol: "https",
        host: organization.domain,
        root: program.root,
        set_locale: @set_locale
      }, ActionMailer::Base.default_url_options)
    end
  end

  private

  def execute_preserving_url_options(&block)
    old_value = ActionMailer::Base.default_url_options
    block.call
    ActionMailer::Base.default_url_options = old_value
  end
end