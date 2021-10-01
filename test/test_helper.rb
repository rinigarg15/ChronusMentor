ENV["RAILS_ENV"] = "test"

if ENV['TDDIUM'] && ENV['CC_TEST_REPORTER_ID']
  require 'simplecov'
  require 'simplecov-json'

  SimpleCov.start 'rails' do
    merge_timeout 3600 # 1 hour
    command_name "rails_app_#{ENV['SOLANO_WORKER_NUM']}_#{$$}"

    add_filter "/vendor/gems/"
    add_filter "/vendor/assets/"
    add_filter "/vendor/plugins/"
    add_filter "/app/assets/"
    add_filter "/lib/tasks/single_time/"
    add_filter "/script/"
  end
end

if ENV['COVERAGE'] == 'true'
  require 'simplecov'
  require 'simplecov-csv'
  require 'simplecov-json'

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CSVFormatter,
    SimpleCov::Formatter::JSONFormatter
  ]

  SimpleCov.start 'rails' do
    merge_timeout 3600 # 1 hour
    add_filter "/vendor/gems/"
    add_filter "/vendor/assets/"
    add_filter "/vendor/plugins/"
    add_filter "/app/assets/"
    add_filter "/lib/tasks/single_time/"
    add_filter "/script/"
  end
end

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'action_view/test_case'
require "minitest/autorun"
require 'test/unit/testcase'
require 'mocha/mini_test'
require "minitest/reporters"
require_relative './minitest_overrides'
require_relative './minitest_reporters_overrides'
require_relative './career_dev_test_helper'
require_relative './authenticated_test_helper'
include ActionView::Helpers::DateHelper
include ActiveSupport::Testing::TimeHelpers

if ENV['TDDIUM']
  Minitest::Reporters.use! Minitest::Reporters::JUnitReporter.new
else
  Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new
end

# This is a workaround for https://github.com/kern/minitest-reporters/issues/230
Minitest.load_plugins
Minitest.extensions.delete('rails')
Minitest.extensions.unshift('rails')
# This is a workaround for https://github.com/kern/minitest-reporters/issues/230

class ActiveSupport::TestCase
  include CareerDevTestHelper

  # This check is required so as to avoid constant redefinition warning.
  # We couldn't move this to test.rb either since this contains reference to
  # model classes and hence resulting in pre-mature load errors.
  unless Test::Unit::TestCase.const_defined?('FIXTURE_CLASS_MAP')
    # Fixture name to class name map to be used in set_fixture_class and
    # rake load_fixtures task.
    Test::Unit::TestCase::FIXTURE_CLASS_MAP = {
      :connection_memberships => Connection::Membership,
      :connection_private_notes => AbstractNote,
      :messages => AbstractMessage,
      :programs => AbstractProgram,
      :article_publications => Article::Publication,
      :mailer_widgets => Mailer::Widget,
      :mailer_templates => Mailer::Template,
      :connection_questions => Connection::Question,
      :connection_answers => Connection::Answer,
      :program_domains => Program::Domain,
      :three_sixty_reviewer_groups => ThreeSixty::ReviewerGroup,
      :three_sixty_competencies => ThreeSixty::Competency,
      :three_sixty_questions => ThreeSixty::Question,
      :three_sixty_surveys => ThreeSixty::Survey,
      :three_sixty_survey_assessees => ThreeSixty::SurveyAssessee,
      :three_sixty_survey_competencies => ThreeSixty::SurveyCompetency,
      :three_sixty_survey_questions => ThreeSixty::SurveyQuestion,
      :three_sixty_survey_assessee_question_infos => ThreeSixty::SurveyAssesseeQuestionInfo,
      :three_sixty_survey_reviewer_groups => ThreeSixty::SurveyReviewerGroup,
      :three_sixty_survey_reviewers => ThreeSixty::SurveyReviewer,
      :three_sixty_survey_answers => ThreeSixty::SurveyAnswer,
      :cm_campaigns => CampaignManagement::AbstractCampaign,
      :cm_campaign_messages => CampaignManagement::AbstractCampaignMessage,
      :cm_email_event_logs => CampaignManagement::EmailEventLog,
      :cm_campaign_message_jobs => CampaignManagement::AbstractCampaignMessageJob,
      :cm_campaign_statuses => CampaignManagement::AbstractCampaignStatus,
      :cm_campaign_emails => CampaignManagement::CampaignEmail,
      :three_sixty_survey_assessee_competency_infos => ThreeSixty::SurveyAssesseeCompetencyInfo,
      :report_sections => Report::Section,
      :report_metrics => Report::Metric,
      :report_alerts => Report::Alert,
      :bulk_matches => AbstractBulkMatch,
      :instructions => AbstractInstruction,
      :summaries => Summary
    }
  end

  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #
  # The only drawback to using transactional fixtures is when you actually
  # need to test transactions.  Since your test is bracketed by a transaction,
  # any transactions started in your code will be automatically rolled back.
  self.use_transactional_tests = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all
  set_fixture_class Test::Unit::TestCase::FIXTURE_CLASS_MAP

  # Add more helper methods to be used by all tests here...
  include AuthenticatedTestHelper


  # This is to get access to <code>fixture_file_upload</code> method even in
  # unit test cases
  # http://rails.lighthouseapp.com/projects/8994/tickets/1985-fixture_file_upload-no-longer-available-in-tests-by-default
  #
  include ActionDispatch::TestProcess

  # include ActionDispatch::Assertions::SelectorAssertions

  # This is to bypass delayed job
  Object.send :alias_method, :old_send_later, :send_later
  Object.send :alias_method, :send_later, :send

  Object.class_eval do
    def send_at(time, method, *args)
      send(method, *args)
    end
  end

  ActionView::TestCase.class_eval do
    def current_user
      @current_user
    end

    def current_member
      @current_member
    end
  end

  attr_accessor :setup_invoked, :teardown_invoked

  # Prepares the helper test
  def helper_setup
    @current_user = User.first
    @current_member = User.first.member
    @controller = ActionView::TestCase::TestController.new
  end

  def setup
    super
    if ENV['PARALLEL_DEBUGGER']
      puts "#{self.class.new(1).method(self.method_name).source_location[0]}"
      puts "#{self.class.name}##{self.method_name}"
    end
    ActionMailer::Base.deliveries.clear
    ChronusElasticsearch.reindex_list = []
    I18n.locale = I18n.default_locale
    Time.zone = TimezoneConstants::DEFAULT_TIMEZONE
    Timecop.return # "turn off" Timecop
    stub_matching_index
    stub_parallel
    stub_push_notifier
    self.setup_invoked = true
    @reindex_mongodb = false
    @dj_source_priority_at_setup = Delayed::Job.source_priority.to_i
    Rails.cache.clear if !Rails.cache.is_a?(ActiveSupport::Cache::FileStore) || File.exists?(Rails.cache.cache_path)
  end

  def after_setup
    super
    raise Exception.new("Call super in setup method") unless self.setup_invoked
  end

  def teardown
    super
    TranslationsService.program = nil # Resetting because the custom terms created for career dev portal clash when other files in the batch are without any login. Read ChronusSessionsControllerTest & CareerDev::PortalsControllerTest
    self.teardown_invoked = true
    Delayed::Job.source_priority = @dj_source_priority_at_setup
  end

  def after_teardown
    super
    raise Exception.new("Call super in teardown method") unless self.teardown_invoked

    reindex_list = ChronusElasticsearch.reindex_list.map { |klass| find_model_with_es_index(klass) }
    reindex_list.uniq.each { |klass| refresh_es_index(klass, nil, false) }
    reset_mongo_index
  end

  def dj_setup
    Object.send :alias_method, :send_later, :old_send_later
    @old_delayed_job_config = Delayed::Worker.delay_jobs
    Delayed::Worker.delay_jobs = true
  end

  def dj_teardown
    Object.send :alias_method, :send_later, :send
    Delayed::Worker.delay_jobs = @old_delayed_job_config
  end

  def reset_mongo_index
    return unless (@reindex_mongodb || @skip_stubbing_match_index) && File.directory?("tmp/matching_test")
    mongodb_db_name = Mongoid::Clients.default.database.name || ENV['TDDIUM_MONGOID_DB']
    system("mongorestore -d #{mongodb_db_name} --dir=tmp/matching_test --drop --quiet")
  end

  def reindex_documents(objects = {})
    ChronusElasticsearch.skip_es_index = false
    Array(objects[:deleted]).map(&:zdt_delayed_delete_es_document)
    Array(objects[:created]).map(&:zdt_delayed_index_es_document)
    Array(objects[:updated]).map(&:zdt_delayed_update_es_document)
    ChronusElasticsearch.skip_es_index = true
    refresh_index_list = Array(objects.values.flatten.compact).map(&:class).uniq.map { |klass| find_model_with_es_index(klass) }
    refresh_index_list.each {|klass| klass.refresh_es_index}
  end

  ##############################################################################
  # Helper Methods
  #############################################################################

  def refresh_es_index(model, includes_list = nil, add_to_reindex_list = true)
    includes_list ||= ElasticsearchConstants::INDEX_INCLUDES_HASH[model.name]
    model.delete_indexes if model.__elasticsearch__.index_exists?
    model.force_create_ex_index
    model.includes(includes_list).eimport
    model.refresh_es_index
    ChronusElasticsearch.reindex_list << model if add_to_reindex_list
  end

  def mongo_reindex(user_ids, program_id)
    @reindex_mongodb = true
    Matching.unstub(:perform_users_delta_index_and_refresh)
    Matching.perform_users_delta_index_and_refresh(Array(user_ids), program_id)
    Matching.stubs(:perform_users_delta_index_and_refresh)
  end

  def template_version_increases_by_one_and_triggers_sync_once(template)
    MentoringModel.expects(:trigger_sync).once
    assert_difference "#{template}.reload.version", 1 do
      yield
    end
  end

  def fixture_file_upload(path, mime_type = nil, binary = false)
    mime_type = MIME::Types.of(path)[0].content_type if mime_type.nil? && MIME::Types.of(path).present?
    super(path, mime_type, binary)
  end

  def current_locale_is(locale)
    @controller.expects(:current_locale).at_least(0).returns(locale)
  end

  # Use this only for functional tests. Don't use this for integration or
  # cucumber tests; instead use #set_current_program_for_integration
  def current_subdomain_is(subdomain, domain = DEFAULT_DOMAIN_NAME)
    @controller.stubs(:current_subdomain).returns(subdomain)
    ActionController::TestRequest.any_instance.stubs(:domain).returns(domain)
  end

  def set_default_host
    host! "#{DEFAULT_SUBDOMAIN}.#{DEFAULT_HOST_NAME}"
  end

  def set_current_organization_for_integration(organization)
    if organization.subdomain
      host! "#{organization.subdomain}.#{organization.domain}"
      set_host_for_capybara(organization.domain, organization.subdomain)
    else
      host! organization.domain
      set_host_for_capybara(organization.domain)
    end
    visit root_organization_path(
    :subdomain => organization.subdomain,
    :host => organization.domain)
  end

  def set_current_program_for_integration(program)
    if program.organization.subdomain
      host! "#{program.organization.subdomain}.#{program.organization.domain}"
      set_host_for_capybara(program.organization.domain, program.organization.subdomain)
    else
      host! program.organization.domain
      set_host_for_capybara(program.organization.domain, nil)
    end

    # Visit the program home page once so that the response object gets set,
    # from which subsequent requests can infer the program.
    visit program_root_url(:root => program.root, :subdomain => program.organization.subdomain, :host => program.organization.domain)
  end

  def set_host_for_capybara(domain, subdomain = nil)
    return # Rails3
    if subdomain
      Capybara.default_host = "#{subdomain}.#{domain}" #for Rack::Test
      Capybara.app_host = "http://#{subdomain}.#{domain}"
    else
      Capybara.default_host = "#{domain}" #for Rack::Test
      Capybara.app_host = "http://#{domain}"
    end
  end

  def mock_parent_session(home_organization, id, additional_data = {})
    organization = home_organization.is_a?(Symbol) ? programs(home_organization) : home_organization

    @request.session[:home_organization_id] = organization.id
    object = mock
    object.stubs(:session_id).returns(id)
    object.stubs(:data).returns( { "home_organization_id" => organization.id }.merge!(additional_data))
    object.stubs(:save!).returns(true)
    ActiveRecord::SessionStore::Session.stubs(:find_by).with(session_id: id).returns(object)
    object
  end

  def allow_one_to_many_mentoring_for_program(program)
    program.update_attribute(:allow_one_to_many_mentoring, true)
    assert program.allow_one_to_many_mentoring?
  end

  def add_roles_to_join_directly_only_with_sso(program, role_list = '')
    role_names = role_list.split(',')
    role_names.each do |role_name|
      prog_role = program.roles.find_by(name: role_name)
      prog_role.membership_request = false
      prog_role.join_directly = false
      prog_role.join_directly_only_with_sso = true
      prog_role.save
    end
  end

  def update_join_setting_for_role(role, setting)
    role.join_directly = false
    role.membership_request = false
    role.join_directly_only_with_sso = false
    case setting
    when RoleConstants::JoinSetting::JOIN_DIRECTLY
      role.join_directly = true
    when RoleConstants::JoinSetting::JOIN_DIRECTLY_ONLY_WITH_SSO
      role.join_directly_only_with_sso = true
    when RoleConstants::JoinSetting::MEMBERSHIP_REQUEST
      role.membership_request = true
    end
    role.save
  end

  def allow_mentee_withdraw_mentor_request_for_program(program, enable_or_disable)
    program.update_attribute(:allow_mentee_withdraw_mentor_request, enable_or_disable)
  end

  # Add an array of users *members* as *role* members to the *group*
  def add_users_to_group(group, members, role)
    allow_one_to_many_mentoring_for_program(group.program)
    if role == :mentor
      new_mentors = (group.mentors + members).uniq
      new_students = group.students
    elsif role == :student
      new_mentors = group.mentors
      new_students = (group.students + members).uniq
    end
    group.update_members(new_mentors, new_students, users(:f_admin))
    assert (members - group.reload.members).blank?
  end

  # Generates a WillPaginate collection from the given array for the given page
  # and per page values
  #
  def wp_collection_from_array(array, page = 1, per_page = PER_PAGE, total_entries = array.size)
    WillPaginate::Collection.create(page, per_page, total_entries) do |pager|
      # Slice to get per_page elements for the given page
      pager.replace((array[((page - 1) * per_page), per_page]) || [])
    end
  end

  # Make the user a member of the program and return user
  def make_member_of(program_arg, user_arg = users(:f_admin))
    program = if program_arg.is_a?(Symbol)
      programs(program_arg)
    else
      program_arg
    end

    user = guess_user(user_arg)
    old_role_names = user.role_names.dup
    user.role_references.destroy_all # Remove all user roles for this program
    user.program = program
    user.save

    member = user.member
    member.organization = program.organization
    member.save

    # Add the same roles from the new program.
    old_role_names.each{|role_name| user.add_role(role_name)}
    user
  end
  # set the current user for the test
  def current_user_is(arg, inferred_from_member = false)
    user = guess_user(arg)
    program = user.program
    current_member_is(user.member) unless inferred_from_member
    current_program_is program

    @request.session[:member_id] = user.member_id
  end

  def current_member_is arg
    member = guess_member(arg)
    @request.session[:member_id] = member.id
    current_organization_is member.organization

    if member.users.size == 1
      current_user_is(member.users.first, true)
    end
  end

  def current_organization_is(arg)
    subdomain, domain = case arg
    when Symbol, String
      [programs(arg).subdomain, programs(arg).domain]
    else
      [arg.subdomain, arg.domain]
    end

    current_subdomain_is(subdomain, domain)
  end

  def get_tmp_language_column(admin_view)
    admin_view.admin_view_columns.new(profile_question_id: nil, column_key: AdminViewColumn::Columns::Key::LANGUAGE, position: admin_view.admin_view_columns.size)
  end

  def get_tmp_mentoring_mode_column(admin_view)
    admin_view.admin_view_columns.new(profile_question_id: nil, column_key: AdminViewColumn::Columns::Key::MENTORING_MODE, position: admin_view.admin_view_columns.size)
  end

  # set the current program by stubbing the subdomain
  def current_program_is(arg)
    program = nil

    if arg.is_a?(Symbol)
      program = programs(arg)
    elsif arg.is_a?(String)
      program = programs(arg.to_sym)
    elsif arg # a Program object
      program = arg
    end

    if program
      current_organization_is(program.organization)
      @controller.expects(:current_root).at_least(0).returns(program.root)
    end
  end

  def set_max_limit_for_group(group, limit, role_name)
    membership_setting = group.membership_settings.find_or_initialize_by(role_id: group.program.get_role(role_name).id)
    membership_setting.max_limit = limit
    membership_setting.save!
  end

  def setup_admin_custom_term(options = {})
    organization = options[:organization] || programs(:org_primary)
    term = options[:term] || "Super Admin"
    admin_term = organization.admin_custom_term
    admin_term.update_term(term: term)
    admin_term.reload
  end

  def enable_project_based_engagements!(program = programs(:albers))
    program.update_attributes!(engagement_type: Program::EngagementType::PROJECT_BASED)
  end

  # Adds the permission with the given name to this role.
  def add_role_permission(role, permission_name)
    role.permissions << Permission.find_by(name: permission_name)
    role.save!
  end

  def remove_role_permission(role, permission_name)
    role.permissions -= Permission.where(name: permission_name)
    role.save!
  end

  # Look at ActionView::TestCase <code>response_from_page_or_rjs</code>
  def set_response_text(string)
    self.rendered = string
  end

  def login_as_super_user
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = true
  end

  def logout_as_super_user
    @request.session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] = false
  end

  def enable_feature(abstract_program, feature)
    abstract_program.enable_feature(feature)
    abstract_program
  end

  def disable_feature(abstract_program, feature)
    abstract_program.enable_feature(feature, false)
    abstract_program
  end

  def fetch_role(program_name, role_name)
    p = programs(program_name)
    role = p.roles.with_name(role_name.to_s).first
    assert role.present?, "Role '#{role_name}' does not exist for program '#{program_name}'"
    return role
  end

  def fetch_connection_membership(role_name, group)
    case role_name
    when :mentor
      group.mentor_memberships.first
    when :student
      group.student_memberships.first
    when :custom
      group.custom_memberships.first
    end
  end

  def fetch_article_label_by_name(name)
    ActsAsTaggableOn::Tag.find_by(name: name)
  end

  #XXX You should be using <code>assert_select_email</code> not this
  def set_response_for_email(email)
    @response = mock("response_object")
    @response.stubs(:content_type).returns "text/html"
    @response.stubs(:body).returns email.body
  end

  def get_html_part_from(email)
    multipart_alternative = email.parts.find{|part| part.content_type =~ /alternative/} || email
    multipart_alternative.parts.find{|part| part.content_type =~ /html/}.body.to_s
  end

  def get_text_part_from(email)
    multipart_alternative = email.parts.find{|part| part.content_type =~ /alternative/} || email
    multipart_alternative.parts.find{|part| part.content_type =~ /plain/}.body.to_s
  end

  def get_calendar_event_part_from(email)
    multipart_alternative = email.parts.find{|part| part.content_type =~ /alternative/} || email
    multipart_alternative.parts.find{|part| part.content_type =~ /calendar/}.body.to_s
  end

  def time_traveller(travel_time)
    raise "No block given" unless block_given?
    Timecop.travel(travel_time)
    yield
    Timecop.return
  end

  def configure_allowed_ips
    organization = programs(:org_primary)
    setting = organization.security_setting
    setting.allowed_ips = "0.0.0.0"
    setting.save!
  end

  def configure_allowed_ips_to_restrict
    organization = programs(:org_primary)
    setting = organization.security_setting
    setting.allowed_ips = "127.0.0.155"
    setting.save!
  end

  def get_partition_size(student_id)
    program = User.find(student_id).program
    program.get_partition_size_for_program
  end

  def set_empty_mentor_cache(student_id)
    @reindex_mongodb = true
    partition = get_partition_size(student_id)
    student_cache = Matching::Database::Score.new.find_by_mentee_id(student_id).first || {}
    Matching::Persistence::Score.where(student_id: student_id).delete_all
    (0...partition).each{ |p_id| Matching::Persistence::Score.collection.insert_one(student_id: student_id, mentor_hash: {}, p_id: p_id) }
  end

  def set_mentor_cache(student_id, mentor_id, score, not_matched = false)
    @reindex_mongodb = true
    partition = get_partition_size(student_id)
    p_id = mentor_id%partition
    student_cache = Matching::Persistence::Score.collection.find(student_id: student_id, p_id: p_id).first || {}
    mentor_hash = student_cache["mentor_hash"] || {}
    mentor_hash["#{mentor_id}"] = [score, not_matched]
    Matching::Persistence::Score.where(student_id: student_id, p_id: p_id).delete_all
    Matching::Persistence::Score.collection.insert_one( { student_id: student_id, mentor_hash: mentor_hash , p_id: p_id} )
  end

  def clear_mentor_cache(student_id, mentor_id)
    @reindex_mongodb = true
    partition = get_partition_size(student_id)
    p_id = mentor_id%partition
    student_cache = Matching::Persistence::Score.collection.find( { student_id: student_id, p_id: p_id } ).first || {}
    mentor_hash = student_cache["mentor_hash"] || {}
    mentor_hash.delete("#{mentor_id}")
    Matching::Persistence::Score.where(student_id: student_id, p_id: p_id).delete_all
    Matching::Persistence::Score.collection.insert_one( { student_id: student_id, mentor_hash: mentor_hash , p_id: p_id} )
  end

  def reset_cache(student)
    @reindex_mongodb = true
    Matching::Cache::Refresh.perform_users_delta_refresh([student.id], student.program_id)
  end

  # For converting hepler output to html content so that assert_select can be used
  def to_html(content)
    Nokogiri::HTML(content).root
  end

  def update_recurring_meeting_start_end_date(meeting, start_time, end_time, options = {})
    meeting.start_time = start_time
    meeting.duration = options[:duration] || 30.minutes
    meeting.end_time = end_time
    meeting.repeats_end_date = (end_time - meeting.duration).to_date
    meeting.recurrent = true
    meeting.schedule_rule = Meeting::Repeats::DAILY
    meeting.repeat_every = 1
    meeting.update_schedule
    meeting.save!
  end

  def update_duration(meeting, new_duration)
    schedule = meeting.schedule
    old_duration = schedule.duration
    schedule.duration = new_duration
    meeting.schedule = schedule
    meeting.end_time = meeting.end_time + (new_duration - old_duration)
    meeting.save!
  end

  def convert_symbol_key_string(hash_array)
    new_hash_array = []
    hash_array.each do |hash|
      new_hash = {}
      hash.keys.each do |key|
        value = hash[key]
        key = key.kind_of?(Symbol) ? key.to_s : key
        new_hash[key] = value
      end
      new_hash_array << new_hash
    end
    return new_hash_array
  end

  def chronus_s3_utils_stub
    ChronusS3Utils::S3Helper.stubs(:transfer).returns('https://s3.amazonaws.com/chronus-mentor-assets/global-assets/files/20140321091645_sample_event.ics')
  end

  def suspend_user(user, reactivation_states = { track: User::Status::ACTIVE })
    user.track_reactivation_state = reactivation_states[:track]
    user.global_reactivation_state = reactivation_states[:global]
    user.suspend!
  end

  def make_user_owner_of_group(group, user)
    group.membership_of(user).update_attributes!(owner: true)
  end

  def stub_saml_sso_files(org_id)
    rails_root = Rails.root.to_s
    files = {
      idp_metadata: {path: File.join(rails_root, "test", "fixtures", "files", "saml_sso", "20140925070519_IDP_Metadata.xml")},
      passphrase: {path: File.join(rails_root, "test", "fixtures", "files", "saml_sso", "20140925070427_passphrase")},
      cert: {path: File.join(rails_root, "test", "fixtures", "files", "saml_sso", "20140925070427_cert.pem")},
      key: {path: File.join(rails_root, "test", "fixtures", "files", "saml_sso", "20140925070427_key.pem")}
    }
    SamlAutomatorUtils::SamlFileUtils.stubs(:get_saml_files_from_s3).returns(files)
    File.stubs(:delete).returns(true)
  end

  # Usage:
  # run_in_another_locale(:"fr-CA") do
      # assert something (This will be executed in fr-CA locale)
  # end
  # After the code is executed, the locale will be set to the original one
  def run_in_another_locale(locale, &block)
    value = nil
    exception = nil
    begin
      orig_locale = I18n.locale
      I18n.locale = locale
      value = block.call
    rescue Exception => e
      execption = e
    ensure
      I18n.locale = orig_locale
      raise execption if execption
      return value
    end
  end

  def with_cache(&block)
    exception = nil
    begin
      ActionController::Base.perform_caching = true
      Rails.cache.clear if !Rails.cache.is_a?(ActiveSupport::Cache::FileStore) || File.exists?(Rails.cache.cache_path)
      block.call
    rescue Exception => e
      exception = e
    ensure
      ActionController::Base.perform_caching = false
      raise exception if exception
    end
  end

  def stubs_uploaded_file_read(upload_object, return_value)
    upload_object.stubs(:path).returns(nil)
    File.stubs(:read).returns(return_value)
  end

  # helper for testing solution pack importers
  def include_importers(*importers_to_import)
    importers_to_import.each do |klass|
      "#{klass}_importer".camelize.constantize.any_instance.expects(:import).once
    end
  end

  ##############################################################################
  # Resource creation helpers
  #############################################################################

  def create_mentoring_model_task_template(options = {})
    MentoringModel::TaskTemplate.create!(options.reverse_merge({
      mentoring_model_id: programs(:albers).mentoring_models.default.first.id,
      role_id: programs(:albers).roles.find{|r| r.name == RoleConstants::MENTOR_NAME }.id,
      title: "task template title",
      duration: 1,
      action_item_type: MentoringModel::TaskTemplate::ActionItem::DEFAULT
    }))
  end

  def create_mentoring_model_facilitation_template(options = {})
    MentoringModel::FacilitationTemplate.create!(options.reverse_merge({
      mentoring_model_id: programs(:albers).mentoring_models.default.first.id,
      roles: programs(:albers).get_roles(RoleConstants::MENTOR_NAME),
      subject: "facilitation template subject",
      message: "facilitation template message",
      send_on: 5
    }))
  end

  def create_mentoring_model_milestone_template(options = {})
    mentoring_model = programs(:albers).mentoring_models.default.first
    last_milestone_template = mentoring_model.reload.mentoring_model_milestone_templates.last
    position = last_milestone_template.present? ? last_milestone_template.position + 1 : 0
    MentoringModel::MilestoneTemplate.create!(options.reverse_merge({
      mentoring_model_id: mentoring_model.id,
      title: "Homeland",
      description: "Carrie thinks a prisoner of war has been turned",
      position: position
    }))
  end

  def create_mentoring_model_goal_template(options = {})
    MentoringModel::GoalTemplate.create!(options.reverse_merge({
      mentoring_model_id: programs(:albers).mentoring_models.default.first.id,
      title: "task template title"
    }))
  end

  def create_mentoring_model_engagement_survey_task_template(options = {})
    create_mentoring_model_task_template(options.reverse_merge({
      action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY,
      action_item_id: surveys(:two).id
    }))
  end

  def create_mentoring_model_task(options = {})
    group = options.delete(:group) || groups(:mygroup)
    user = options.delete(:user) || users(:f_mentor)
    options[:due_date] ||= 3.weeks.from_now if options[:required]
    options[:template_version] ||= 1 if options[:from_template]
    task = MentoringModel::Task.create!(options.reverse_merge({
      connection_membership_id: Connection::Membership.where(group_id: group.id, user_id: user.id)[0].id,
      group_id: group.id,
      required: false,
      title: "task title",
      status: MentoringModel::Task::Status::TODO,
      action_item_type: MentoringModel::TaskTemplate::ActionItem::DEFAULT
    }))
    return task
  end

  def create_mentoring_model_milestone(options = {})
    options[:template_version] ||= 1 if options[:from_template]
    last_milestone = groups(:mygroup).reload.mentoring_model_milestones.last
    position = last_milestone.present? ? last_milestone.position + 1 : 0
    mentoring_model_milestone = MentoringModel::Milestone.create!(options.reverse_merge({
      group_id: groups(:mygroup).id,
      title: "Carrie Mathison",
      description: "Homeland",
      position: position
    }))
    mentoring_model_milestone.from_template = options[:from_template] unless options[:from_template].nil?
    mentoring_model_milestone.save!
    mentoring_model_milestone
  end

  def create_education(user, question, options = {})
    user_or_member = user.is_a?(Member) ? user : user.member
    answer = user_or_member.answer_for(question) || user_or_member.profile_answers.build( :profile_question => question)
    education = answer.educations.build({:school_name => "SSV",
        :degree => "BTech",
        :major => "IT",
        :graduation_year => 2009}.merge(options))
    education.profile_answer = answer
    answer.save!
    education
  end

  def create_experience(user, question, options = {})
    user_or_member = user.is_a?(Member) ? user : user.member
    answer = user_or_member.answer_for(question) || user_or_member.profile_answers.build( :profile_question => question)
    experience = answer.experiences.build({:job_title => "SDE",
        :start_year => 2000,
        :end_year => 2009,
        :company => "MSFT"}.merge(options))
    experience.profile_answer = answer
    answer.save!
    experience
  end

  def create_publication(user, question, options = {})
    user_or_member = user.is_a?(Member) ? user : user.member
    answer = user_or_member.answer_for(question) || user_or_member.profile_answers.build( :profile_question => question)
    publication = answer.publications.build({:title => "Publication",
        :publisher => 'Publisher ltd.',
        :year => 2009,
        :month => 1,
        :day => 3,
        :url => "http://public.url",
        :authors => "Author",
        :description => 'Very useful publication'
      }.merge(options))
    publication.profile_answer = answer
    answer.save!
    publication
  end

  def create_manager(user, question, options = {})
    user_or_member = user.is_a?(Member) ? user : user.member
    answer = user_or_member.answer_for(question) || user_or_member.profile_answers.build( :profile_question => question)
    options = {
        :first_name => "Manager",
        :last_name => 'Name',
        :email => 'manager@example.com'
      }.merge(options)
    manager = if answer.manager.nil?
      answer.build_manager(options)
    else
      mgr = answer.manager
      mgr.assign_attributes(options)
      mgr
    end
    manager.profile_answer = answer
    manager.program = user.program if user.is_a?(User)
    answer.save!
    manager
  end

  def create_education_answers(user_or_member, question, options_array)
    member = user_or_member.is_a?(User) ? user_or_member.member : user_or_member
    answer = member.profile_answers.build(profile_question: question)
    options_array.each do |options|
      answer.educations.build(options) do |ed|
        ed.profile_answer = answer
      end
    end
    answer.save!
  end

  def create_experience_answers(user, question, options_array)
    answer = user.member.profile_answers.build(profile_question: question)
    options_array.each do |options|
      answer.experiences.build(options) do |ed|
        ed.profile_answer = answer
      end
    end
    answer.save!
  end

  def create_publication_answers(user, question, options_array)
    answer = user.member.profile_answers.build(profile_question: question)
    options_array.each do |options|
      answer.publications.build(options) do |ed|
        ed.profile_answer = answer
      end
    end
    answer.save!
  end

  def create_mentor_request(options = {})
    program = options[:program] || programs(:albers)
    mentor = (options[:mentor] || users(:f_mentor)) if program.matching_by_mentee_alone?
    req = MentorRequest.new({
        :message => options[:message] || "Hi",
        :program => program,
        :student => options[:student] || users(:f_student),
        :mentor => mentor}.merge(options))

    if options[:status] == AbstractRequest::Status::REJECTED
      req.response_text = options[:response_text] || "Sorry"
    end

    req.save!
    return req
  end

  def create_mentor_request_instruction(options = {})
    program = options[:program] || programs(:albers)
    content = options[:content] || "Sample Mentor Request Instruction"
    instruction = program.mentor_request_instruction || MentorRequest::Instruction.new(program: program)
    instruction.content = content
    instruction.save!
    instruction
  end

  def create_meeting_request(options = {})
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes)
    req = meeting.meeting_request
    program = options[:program] || programs(:albers)
    mentor = (options[:mentor] || users(:f_mentor)) if program.matching_by_mentee_alone?
    req.update_attributes({
        :message => options[:message] || "Hi",
        :program => program,
        :student => options[:student] || users(:f_student),
        :mentor => mentor}.merge(options))

    if options[:status] == AbstractRequest::Status::REJECTED
      req.response_text = options[:response_text] || "Sorry"
    end

    req.save!
    return req
  end

  def create_meeting_proposed_slot(options = {})
    time = 3.days.from_now
    options[:start_time] ||= time
    options[:end_time] ||= time + 20.minutes
    options[:location] ||= "Test location"
    options[:meeting_request_id] ||= create_meeting_request.id
    options[:proposer_id] ||= users(:f_student).id
    MeetingProposedSlot.create!(options)
  end

  def create_object_role_permission(permission, options = {})
    program = options[:program] || programs(:albers)
    object = options[:object] || program.default_mentoring_model
    role = options[:role] || "admin"
    action = options[:action] || "allow"

    roles_hash = program.roles.select([:id, :name]).for_mentoring_models.group_by(&:name)
    admin_role = roles_hash[RoleConstants::ADMIN_NAME].first
    mentor_role = roles_hash[RoleConstants::MENTOR_NAME].first
    student_role = roles_hash[RoleConstants::STUDENT_NAME].first

    roles_array = [admin_role]
    roles_array = [mentor_role, student_role] if role == 'users'

    object.send("#{action}_#{permission}!", roles_array)
  end

  def create_mentoring_offer_direct_addition
    prog = programs(:albers)
    student = users(:student_6)
    mentor = users(:mentor_6)
    group = prog.groups.new
    group.mentors = [mentor]
    group.students = [student]
    group.offered_to = student
    group.actor = mentor
    assert_difference 'RecentActivity.count' do
      group.save!
    end

    return group
  end

  def create_mentor_offer(options = {})
    program = options[:program] || programs(:albers)
    mentor = options[:mentor] || users(:f_mentor)
    student = options[:student] || users(:f_student)
    group = options[:group] || nil
    mentor.update_attribute(:max_connections_limit, options[:max_connection_limit] || 10)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    offer = MentorOffer.new({
        :program => program,
        :mentor => mentor,
        :student => student,
        :group => group,
        :status => MentorOffer::Status::PENDING})

    offer.save!
    return offer
  end

  def create_qa_question(options = {})
    user = options.delete(:user)
    program = options.delete(:program)
    views = options.delete(:views)
    qa_question = QaQuestion.new({:summary => "Hello",:description => "How are you?"}.merge(options))
    qa_question.user = user || users(:f_admin)
    qa_question.program = program || programs(:albers)
    qa_question.views = views || 10
    qa_question.save!
    return qa_question
  end

  def create_qa_answer(options = {})
    qa_question = options[:qa_question] || create_qa_question
    user = options.delete(:user)
    qa_answer = QaAnswer.new({:content => "Hi", :qa_question => qa_question}.merge(options))
    qa_answer.user = user || users(:f_student)
    qa_answer.save!
    return qa_answer
  end

  def create_flag(options = {})
    content = articles(:economy)
    program = programs(:albers)
    user = users(:f_student)
    reason = 'offensive'
    status = Flag::Status::UNRESOLVED
    flag = Flag.create!({reason: reason, content: content, program: program, user: user, status: status}.merge(options))
    return flag
  end

  def create_data_import(options = {})
    org = programs(:org_primary)
    status = DataImport::Status::SUCCESS
    source_file = fixture_file_upload(File.join("files","20130205043201_data_feed.csv"), "csv")
    di = DataImport.create!({organization_id: org.id, status: status, source_file: source_file}.merge(options))
  end

  def create_group(options = {})
    students = options.delete(:student)
    students ||= options.delete(:students) || [users(:f_student)]
    students = [students].flatten

    # Handle passing a single mentor.
    mentors = options.delete(:mentor)
    mentors ||= options.delete(:mentors) || [users(:f_mentor)]
    mentors = [mentors].flatten

    prog = options[:program] || mentors.first.program
    status = options[:status] || Group::Status::ACTIVE
    notes = options[:notes]
    g = Group.new({program: prog, mentors: mentors, students: students, notes: notes}.merge(options))
    g.status = status
    g.save!
    return g
  end

  def create_scrap(options = {})
    group_or_meeting = options.delete(:group) || create_group
    sender = options.delete(:sender) || (group_or_meeting.is_a?(Group) ? group_or_meeting.members.first.member : group_or_meeting.members.first)
    subject = options.delete(:subject) || 'subject'
    content = options.delete(:content) || 'This is the content.'
    program = options.delete(:program) || group_or_meeting.program

    scrap = Scrap.new({
              :program => program,
              :subject => subject,
              :content => content,
              :sender => sender,
              :ref_obj => group_or_meeting}.merge(options))

    scrap.receiving_users.each do |receiving_user|
      scrap.message_receivers.build(:member => receiving_user.member)
    end
    scrap.save!
    scrap
  end

  def create_resource(options = {})
    programs = options.delete(:programs)
    resource = Resource.new({:title => "New resource", :content => "New content"}.merge(options))
    resource.organization = options[:organization] || programs(:org_primary)
    resource.save!
    if programs.present?
      programs.each do |program, role_ids|
        create_resource_publication(resource: resource, program: program).role_ids = role_ids
      end
    end
    resource
  end

  def create_resource_publication(options = {})
    resource = options.delete(:resource) || create_resource
    program = options.delete(:program) || programs(:albers)
    ResourcePublication.create!(
      {
        program: program,
        resource: resource,
        position: program.resource_publications.maximum(:position).to_i + 1
      }.merge(options)
    )
  end

  def create_theme(options = {})
    if options.has_key?(:program)
      program = options.delete(:program)
    else
      program = programs(:org_primary)
    end
    css_file = options.delete(:css) || fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
    theme = Theme.new({:name => options.delete(:name) || 'New Theme',
                   :css => css_file,
                   :program => program
                  }.merge(options))
    theme.temp_path = css_file.path
    theme.save!
    return theme
  end

  def create_forum(options = {})
    access_role_names = options.delete(:access_role_names) || RoleConstants::MENTOR_NAME

    forum = Forum.new( { name: "Exclusive Mentor Forum" }.merge(options))
    forum.program = options[:program] || programs(:albers)
    forum.access_role_names = access_role_names if forum.is_program_forum?
    forum.save!
    forum
  end

  def create_topic(options = {})
    topic = Topic.new
    topic.title = options[:title] || "Title"
    topic.body = options[:body] || "This is the body"
    topic.user = options[:user] || users(:f_admin)
    topic.forum = options[:forum] || forums(:common_forum)
    topic.hits = options[:hits].to_i
    topic.sticky_position = options[:sticky_position].to_i
    topic.save!
    topic
  end

  def create_old_topic(options = {})
    topic = nil
    time_traveller(1.day.ago) do
      topic = create_topic(options)
    end
    topic
  end

  def create_post(options = {})
    post = Post.new
    post.body = options[:body] || "test body"
    post.attachment = options[:attachment]
    post.topic = options[:topic]
    post.user = options[:user] || users(:f_admin)
    post.ancestry = options[:ancestry]
    post.published = options.has_key?(:published) ? options[:published] : true
    post.save!
    post
  end

  def create_article(options = {})
    a = build_article(options)
    a.save!
    a
  end

  def build_article(options = {})
    a = Article.new

    a.organization = options[:organization] || programs(:org_primary)
    a.author = options[:author] || members(:f_mentor)
    a.article_content = options[:article_content] || a.build_article_content(
      :title => (options[:title] || "Test title"),
      :body => (options[:body] || "Test body"),
      :type => (options[:type] || "text"),
      :embed_code => options[:embed_code],
      :status => (options[:status] || ArticleContent::Status::PUBLISHED)
    )
    a.published_programs = options[:published_programs] || [programs(:albers)]

    return a
  end

  def create_upload_article_content
    a = ArticleContent.new(
      :title => 'test',
      :body => "<script>alert(1)</script>",
      :type => ArticleContent::Type::UPLOAD_ARTICLE,
      :status => ArticleContent::Status::PUBLISHED,
      :attachment_file_name => "some_file.pdf",
      :attachment_file_size => 20.megabytes,
      :attachment_content_type => "application/pdf"
    )
    a.save!
    return a
  end

  def create_favorite_preference(options = {})
    preference_marker_user = options[:preference_marker_user] || users(:f_student)
    preference_marked_user = options[:preference_marked_user] || users(:f_mentor)
    favorite = FavoritePreference.new({preference_marker_user: preference_marker_user, preference_marked_user: preference_marked_user}.merge(options))

    favorite.save!
    return favorite
  end

  def create_ignore_preference(options = {})
    preference_marker_user = options[:preference_marker_user] || users(:f_student)
    preference_marked_user = options[:preference_marked_user] || users(:f_mentor)
    ignored = IgnorePreference.new({preference_marker_user: preference_marker_user, preference_marked_user: preference_marked_user}.merge(options))

    ignored.save!
    return ignored
  end

  def create_article_draft(options = {})
    create_article(options.merge({
      :status => ArticleContent::Status::DRAFT,
      :published_programs => []})
    )
  end

  def create_article_publication(article, program)
    Article::Publication.create!(:article => article, :program => program)
  end

  def create_article_comment(article, program, attrs)
    article.get_publication(program).comments.create!(attrs)
  end

  def remove_mentor_request_permission_for_students(program = programs(:albers))
    program.get_role(RoleConstants::STUDENT_NAME).remove_permission("send_mentor_request")
  end

  def remove_manage_email_templates_permission_for_admins(program = programs(:albers))
    program.get_role(RoleConstants::ADMIN_NAME).remove_permission("manage_email_templates")
  end

  # Creates, saves and returns a new User record overriding default fields if
  # given in options.
  #
  def create_user(options = {})
    first_name = options[:first_name] || "first_name"
    last_name =  options[:last_name] || options[:name] || 'some_name'
    program = options.delete(:program) || programs(:albers)
    member = options.delete(:member)
    unless member
      member = Member.create!(
        :organization => program.organization,
        :first_name => first_name,
        :last_name => last_name,
        :email => options[:email] || (last_name.gsub(/\s+/, '_') + "@chronus.com"),
        :password => options[:password] || 'monkey',
        :password_confirmation => options[:password_confiramtion] || 'monkey'
      )
      member.accept_terms_and_conditions!
    end

    role_names = options.delete(:role_names) || RoleConstants::STUDENT_NAME
    options.delete(:name)
    options.delete(:email)
    options.delete(:first_name)
    options.delete(:last_name)
    options.delete(:location_name)
    state = options.delete(:state)
    created_by = options.delete(:created_by)
    imported_from_other_program = options.delete(:imported_from_other_program)
    user = User.new(options)
    user.member = member
    user.program = program
    user.role_names = role_names
    user.created_by = created_by
    user.state = state || User::Status::ACTIVE
    user.max_connections_limit
    user.last_program_update_sent_time = options[:last_program_update_sent_time] || 2.days.ago
    user.imported_from_other_program = imported_from_other_program
    user.save!
    if options[:program_notification_setting]
      user.program_notification_setting = options[:program_notification_setting]
      user.save!
    end
    user.reload
    user.roles.reload
    return user
  end

  # Creates, saves and returns a new User record overriding default fields if
  # given in options.
  #
  def create_member(options = {})
    Location.expects(:find_or_create_by_full_address).at_least(0).returns(locations(:chennai))
    first_name = options[:first_name] || "first_name"
    last_name =  options[:last_name] || options[:name] || 'some_name'
    program = options[:program] || programs(:albers)
    organization = options[:organization] || program.organization
    options.delete(:name)
    skip_tnc_acceptance = options.delete(:skip_tnc_acceptance)
    me = Member.new({
        :organization => organization,
        :first_name => first_name,
        :last_name => last_name,
        :email => options[:email] || last_name.gsub(/\s+/, '_') + "@chronus.com",
        :password => 'test123',
        :password_confirmation => 'test123'
      }.merge(options))
    me.save!
    me.accept_terms_and_conditions! unless skip_tnc_acceptance
    me
  end

  # Creates profile picture for the user with the data in options[:image]
  def create_profile_picture(member, options = {})
    options[:image] ||= fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    member.profile_picture = ProfilePicture.new(options)
    member.save!
  end

  def create_announcement(attrs = {})
    role_names = attrs.delete(:recipient_role_names) || programs(:albers).roles_without_admin_role.collect(&:name)
    admin = attrs.delete(:admin)
    program = attrs.delete(:program)
    announcement = Announcement.new({:title => "Hello"}.merge(attrs))
    announcement.admin = admin || users(:f_admin)
    announcement.program = program || programs(:albers)
    announcement.recipient_role_names = role_names
    announcement.email_notification = attrs[:email_notification] || UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND
    announcement.save!
    return announcement
  end

  def create_viewed_object(attrs = {})
    viewed_object = ViewedObject.new(attrs)
    viewed_object.save!
    return viewed_object
  end

  def create_chronus_version(attrs = {})
    chronus_version = ChronusVersion.new(attrs)
    chronus_version.save!
    return chronus_version
  end

  def create_job_log(options = {})
    user = options[:user] || users(:f_mentor)
    user.job_logs.create!(
      loggable_object: options[:object] || (announcement = create_announcement),
      action_type: options[:action_type] || RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      version_id: options[:version_id] || (options[:object] && options[:object].version_number) || announcement.version_number
    )
  end

  def create_pending_notification(opts = {})
    announcement_opts = opts.delete(:announcement_opts) || {}
    ref_obj = opts.delete(:ref_obj) || create_announcement(announcement_opts)
    options = {
      :ref_obj_creator => users(:f_mentor),
      :program => programs(:albers),
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :ref_obj => ref_obj
    }.merge(opts)

    PendingNotification.create!(options)
  end

  def create_pending_notification_program_event(opts = {})
    options = {
      :ref_obj_creator => users(:ram),
      :program => programs(:albers),
      :action_type => RecentActivityConstants::Type::PROGRAM_EVENT_CREATION,
      :ref_obj => ProgramEvent.first
    }.merge(opts)

    PendingNotification.create!(options)
  end

  def create_pending_notification_for_mentee(opts = {})
    announcement_opts = opts.delete(:announcement_opts) || {}
    options = {
      :ref_obj_creator => users(:f_student),
      :program => programs(:albers),
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :ref_obj => create_announcement(announcement_opts)
    }.merge(opts)

    PendingNotification.create!(options)
  end

  def create_push_notification(options = {})
    member = options[:member] || members(:f_mentor)
    ref_obj = options[:ref_obj] || create_announcement
    notification_type = options[:notification_type] || PushNotification::Type::ANNOUNCEMENT_NEW
    notification_params = options[:notification_params].to_h.reverse_merge(object_id: ref_obj.id, category: ref_obj.class.name)

    member.push_notifications.create!(
      notification_params: notification_params,
      ref_obj_id: ref_obj.id,
      ref_obj_type: ref_obj.class.name,
      notification_type: notification_type
    )
  end

  def create_recent_activity(options = {})
    options = options.reverse_merge(
      :programs  => [programs(:albers)],
      :target => RecentActivityConstants::Target::ALL
    )
    RecentActivity.create!(options)
  end

  def create_organization_feature(opts = {})
    options = {
      :feature => Feature.find_by(name: FeatureName::ARTICLES),
      :organization_id => programs(:org_primary).id
    }.merge(opts)

    OrganizationFeature.create!(options)
  end

  def create_survey(attrs = {})
    survey_type = attrs.delete(:type).constantize
    attrs.reverse_merge!(
      :program => programs(:albers),
      :name => "Some survey")

    role_names = attrs.delete(:recipient_role_names) || [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    survey = survey_type.new(attrs)
    survey.recipient_role_names = role_names if survey.program_survey?
    survey.save!
    return survey
  end

  def create_program_survey(attrs = {})
    create_survey(attrs.merge(:type => "ProgramSurvey"))
  end

  def create_engagement_survey(attrs = {})
    create_survey(attrs.merge(:type => "EngagementSurvey"))
  end

  def create_common_question(options = {})
    question_choices = options.delete(:question_choices) || options.delete(:question_info) || []
    question_choices = question_choices.split(",").map(&:strip).reject(&:blank?) if(question_choices.is_a?(String))
    options.reverse_merge!(
      :program => programs(:albers),
      :question_type => CommonQuestion::Type::STRING,
      :question_text => "Whats your age?")

    common_question = CommonQuestion.new(options)
    common_question.required = options[:required] || false
    common_question.save!
    question_choices.each_with_index {|text, pos| common_question.question_choices.create!(text: text, position: pos + 1)}
    return common_question
  end


  # Creates a SupplementaryMatchingPair
  def create_supplementary_matching_question_pair(options = {})
    attributes = {
      student_role_question: role_questions(:role_questions_15),
      mentor_role_question: role_questions(:role_questions_16),
      program: role_questions(:role_questions_15).program
    }.merge!(options)

    SupplementaryMatchingPair.create!(attributes)
  end

  # Creates a question
  def create_question(options = {})
    options.reverse_merge!(:organization => programs(:org_primary), :question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?")
    filterbale = options.delete(:filterable)
    available_for = options.delete(:available_for) || RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS
    rq_options = {:program => options.delete(:program) || programs(:albers), :role_names => options.delete(:role_names) || [RoleConstants::STUDENT_NAME], :required => options.delete(:required) || false, :filterable => filterbale.nil? ? true : filterbale, :private => options.delete(:private), :privacy_settings => options.delete(:privacy_settings), :available_for => available_for}
    pq = create_profile_question(options)
    rq_options[:profile_question] = pq
    create_role_question(rq_options)

    return pq.reload
  end

  # TODO_PROFILE_CONFIG_UI : the migration not getting applied since fixture generator is run afterwards
  def update_profile_question_types_appropriately
    ProfileQuestion.where(question_type: ProfileQuestion::Type::EDUCATION).update_all(question_type: ProfileQuestion::Type::MULTI_EDUCATION)
    ProfileQuestion.where(question_type: ProfileQuestion::Type::EXPERIENCE).update_all(question_type: ProfileQuestion::Type::MULTI_EXPERIENCE)
    ProfileQuestion.where(question_type: ProfileQuestion::Type::PUBLICATION).update_all(question_type: ProfileQuestion::Type::MULTI_PUBLICATION)
  end

  # Creates a profile question
  def create_profile_question(options = {})
    question_choices = options.delete(:question_choices) || []
    condtional_choices = options.delete(:conditional_match_text) || ""
    question_choices = question_choices.split(",") if question_choices.is_a?(String)
    options.reverse_merge!(
      :organization => programs(:org_primary), :question_type => ProfileQuestion::Type::STRING,
      :question_text => "Whats your age?")
    question = ProfileQuestion.new(options)
    question.section = options[:organization].sections.default_section.first
    question.save!
    question_choices.each_with_index do |text, index|
      question.question_choices.create!(text: text, position: index + 1)
    end
    condtional_choices.split(",").each do |choice|
      qc = question.conditional_question.question_choices.find_by(text: choice)
      question.conditional_match_choices.create!(question_choice_id: qc.id)
    end
    question.reload
  end

  # Creates a role question
  def create_role_question(options = {})
    options.reverse_merge!(:program => programs(:albers))
    role_names = options.delete(:role_names)
    program = options.delete(:program)
    role = program.roles.with_name(role_names)[0]
    options[:private] ||= RoleQuestion::PRIVACY_SETTING::ALL
    privacy_settings = options.delete(:privacy_settings)
    question = RoleQuestion.new(options)
    question.role = role
    question.save!
    if question.private == RoleQuestion::PRIVACY_SETTING::RESTRICTED
      privacy_settings.each do |type, role_id|
        question.privacy_settings.create!(setting_type: type, role_id: role_id)
      end
    end
    question
  end

  # Create a meeting but don't save
  def create_meeting(options = {})
    force_non_group_meeting = !!options.delete(:force_non_group_meeting)
    force_non_time_meeting = !!options.delete(:force_non_time_meeting)
    options.merge!(calendar_time_available: !force_non_time_meeting)
    options[:topic] ||= "General Topic"
    time = 60.minutes.ago
    options[:start_time] ||= time
    options[:end_time] ||= time + 20.minutes
    options[:description] ||= "This is a description of the meeting"
    options[:group_id] ||= (force_non_time_meeting || force_non_group_meeting) ? nil : groups(:mygroup).id
    options[:members] ||= [members(:f_mentor), members(:mkr_student)]
    options[:owner_id] ||= members(:f_mentor).id
    options[:program_id] ||= programs(:albers).id
    options[:requesting_mentor] ||=  users(:f_mentor)
    options[:requesting_student] ||=  users(:mkr_student)
    options[:mentor_created_meeting] ||= false
    options[:mentee_id] = options[:requesting_student].member.id
    Meeting.create!(options)
  end

  def invalidate_albers_calendar_meetings
    meetings(:upcoming_calendar_meeting).false_destroy!
    meetings(:past_calendar_meeting).false_destroy!
    meetings(:completed_calendar_meeting).false_destroy!
    meetings(:cancelled_calendar_meeting).false_destroy!
  end

  def create_mentoring_slot(options = {})
    options[:start_time] ||= 40.minutes.since
    options[:end_time] ||= 60.minutes.since
    options[:repeats] ||= MentoringSlot::Repeats::WEEKLY
    options[:repeats_on_week] ||= 40.minutes.since.wday.to_s
    MentoringSlot.create(options)
  end

  def create_login_token(options = {})
    options[:member] ||= members(:f_mentor)
    LoginToken.create(options)
  end

  def create_user_search_activity(options = {})
    options[:user] ||= users(:f_mentor)
    options[:program] ||= programs(:albers)
    UserSearchActivity.create(options)
  end

  # Creates a SurveyQuestion
  def create_survey_question(options = {})
    question_choices = options.delete(:question_choices) || options.delete(:question_info) || []
    question_choices = question_choices.split(",").map(&:strip) if(question_choices.is_a?(String))
    options.reverse_merge!(
      program: programs(:albers),
      question_type: CommonQuestion::Type::STRING,
      question_text: "Whats your age?")

    options.reverse_merge!({survey:  surveys(:one)})
    sq = SurveyQuestion.create!(options)
    question_choices.each_with_index {|text, pos| sq.question_choices.create!(text: text, position: pos + 1)}
    sq
  end

  def create_matrix_survey_question(options = {})
    options.reverse_merge!(
      program: programs(:albers),
      question_type: CommonQuestion::Type::MATRIX_RATING,
      question_text: "Rate yourself on the following"
      )

    options.reverse_merge!({survey:  surveys(:one)})
    mq = SurveyQuestion.new(options)

    mrq_options = options.reverse_merge!(
      program: programs(:albers))

    mrq_options[:question_type] = CommonQuestion::Type::RATING_SCALE

    (options[:matrix_rating_question]||["Leadership","Team Work","Communication"]).each_with_index do |mrq, index|
      mrq_options.merge!(question_text: mrq, matrix_position: index)
      options.reverse_merge!(matrix_question_id: mq.id)
      mq.rating_questions.new(mrq_options)
    end
    mq.save!
    ["Very Good", "Good", "Average", "Poor"].each_with_index {|text, pos| mq.question_choices.create!(text: text, position: pos + 1)}
    return mq
  end

  def create_feedback_question(attrs = {})
    attributes = {
      :program => programs(:albers),
      :question_type => CommonQuestion::Type::STRING,
      :question_text => "Whats your age?",
      :role_names => [RoleConstants::STUDENT_NAME]}
    attributes.merge!(attrs)

    Feedback::Question.create!(attributes)
  end

  def create_feedback_answer(attrs = {})
    attrs.reverse_merge!(
      :user => users(:f_student),
      :answer_text => "string answer")

    Feedback::Answer.create!(attrs)
  end

  # Creates a Profile Question for the Membership Form
  def create_membership_profile_question(options = {})
    options.reverse_merge!(
      :organization => programs(:org_primary),
      :question_type => ProfileQuestion::Type::STRING,
      :question_text => "Whats your age?"
      )
    options[:section] ||= programs(:org_primary).sections.default_section.first

    if options[:program]
      program = options.delete(:program)
    else
      program = programs(:albers)
    end

    if options[:role_names]
      roles = options.delete(:role_names)
    else
      roles = [RoleConstants::MENTOR_NAME]
    end
    question_choices = options.delete(:question_choices) || []
    pq = ProfileQuestion.create!(options)
    question_choices.each do |text|
      pq.question_choices.create!(text: text)
    end
    roles.each do |role|
      role = program.get_role(role)
      pq.role_questions.create!(:role => role, :available_for => RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    end
    pq
  end

  # Creates a SurveyAnswer
  def create_survey_answer(options = {})
    options.reverse_merge!(
      :user => users(:f_student),
      :answer_text => "string answer",
      :response_id => 1,
      :last_answered_at => Time.now)

    survey = options.delete(:survey) || surveys(:one)
    options[:survey_question] ||= create_survey_question(
      {:program => survey.program, :survey => survey})

    SurveyAnswer.create!(options)
  end

  def create_mentor_question(options = {})
    options.reverse_merge!(:organization => programs(:org_primary),
      :question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?")
    options[:section] = programs(:org_primary).sections.default_section.first
    required = options.delete(:required)
    prof_ques = ProfileQuestion.create!(options)
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    prof_ques.role_questions.create!(:role => mentor_role, :required => required.present?)
  end

  def create_student_question(options = {})
    options.reverse_merge!(:organization => programs(:org_primary),
      :question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?")
    options[:section] = programs(:org_primary).sections.default_section.first
    required = options.delete(:required)
    prof_ques = ProfileQuestion.create!(options)
    student_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    prof_ques.role_questions.create!(:role => student_role, :required => required.present?)
  end

  # Create a profile section
  def create_section(opts = {})
    opts.reverse_merge!(:program => programs(:albers), :title => "Section name", :role_names => [RoleConstants::MENTOR_NAME])
    Section.create!(opts)
  end

  def create_location(options)
    Location.create!({:city => "Chennai",
        :state => "Tamilnadu",
        :country => "India",
        :lat => 13.060416,
        :full_address => "Chennai, Tamilnadu, India",
        :lng => 80.249634}.merge(options))
  end

  def create_message(options = {})
    receiver = options.delete(:receiver)
    receivers = receiver ? [receiver] : options.delete(:receivers) || [members(:f_mentor)]
    Message.create!({
      :sender => members(:f_mentor_student), :receivers => receivers, :organization => programs(:org_primary),
      :subject => "This is subject", :content => "This is content"}.merge(options))
  end

  def create_message_reply(message, options = {})
    Message.create!({
      parent_id: message.id,
      root_id: options[:root_id] || message.id,
      sender: options[:sender] || message.receivers.first, receivers: [message.sender], organization: message.organization,
      subject: message.subject, content: "Re: #{message.content}"}.merge(options))
  end

  def create_admin_message(options = {})
    unless options[:receivers]
      msg_recevier_attrs = {:member => options.delete(:receiver), :email => options.delete(:receiver_email), :name => options.delete(:receiver_name), :status => options.delete(:status) || AbstractMessageReceiver::Status::UNREAD}
      a = AdminMessage.new({:program => programs(:albers), :subject => "This is subject", :content => "This is content"}.merge(options))
      a.message_receivers.build(msg_recevier_attrs)
      a.message_receivers.each do |msg_rec|
        msg_rec.message = a
      end
    else
      a = AdminMessage.new({:program => programs(:albers), :subject => "This is subject", :content => "This is content"}.merge(options))
    end

    a.save!
    return a
  end

  def create_translation_import(options = {})
    unless options[:program].nil?
      translation_import = options[:program].translation_imports.new
      translation_import.attachment = options[:attachment]
      translation_import.local_csv_file_path = options[:local_csv_file_path]
      translation_import.info = options[:info]
      translation_import.save!
      return translation_import
    else
      return nil
    end
  end

  def create_permission(name = 'do_something')
    Permission.create!(:name => name)
  end

  def create_role(options = {})
    Role.create!({:name => 'some_role', :program => programs(:albers)}.merge(options))
  end

  def create_organization_language(options = {})
    language = options.delete(:language) || languages(:hindi)
    organization = options.delete(:organization) || programs(:org_primary)
    organization_language = OrganizationLanguage.create!({
        organization: organization,
        enabled: OrganizationLanguage::EnabledFor::ALL,
        language: language,
        title: language.title,
        display_title: language.display_title
      }.merge(options))
    organization_language.send :enable_for_program_ids, organization.program_ids
    organization_language
  end

  def create_language(options = {})
    Language.create!({
        :display_title  => 'French',
        :title          => 'Frenchulu',
        :language_name  => 'fr',
        :enabled        => true
      }.merge(options))
  end

  def create_program_language(options = {})
    ProgramLanguage.create!({
      program: programs(:albers),
      organization_language: organization_languages(:hindi)
    }.merge(options))
  end

  def create_bulk_match(options = {})
    program = options[:program] || programs(:albers)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    mentee_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    mentor_view_id = options[:mentor_view_id] || mentor_view.id
    mentee_view_id = options[:mentee_view_id] || mentee_view.id
    orientation_type = options[:orientation_type] || BulkMatch::OrientationType::MENTEE_TO_MENTOR
    klass = options[:type] || BulkMatch.name
    max_pickable_slots = options[:max_pickable_slots] || 2
    max_suggestion_count = options[:max_suggestion_count] || 1
    bulk_match = klass.constantize.create!(:program => program, :mentor_view_id => mentor_view_id, :mentee_view_id => mentee_view_id, max_suggestion_count: max_suggestion_count, max_pickable_slots: max_pickable_slots, orientation_type: orientation_type)
  end

  def create_match_report_admin_view(options = {})
    program = options.delete(:program) || programs(:albers)
    admin_view = options.delete(:admin_view) || program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    MatchReportAdminView.create!(
      {
        program: program,
        admin_view: admin_view,
        section_type: MatchReport::Sections::MentorDistribution,
        role_type: RoleConstants::MENTOR_NAME
      }.merge(options)
    )
  end

  def create_mentor_recommendation_and_preferences(receiver_id, status, mentor_ids = [])
    mentor_recommendation = programs(:albers).mentor_recommendations.create!(receiver_id: receiver_id, status: status, sender_id: 1)
    mentor_ids.each_with_index do |id, index|
      mentor_recommendation.recommendation_preferences.create!(user_id: id, position: index + 1)
    end
    mentor_recommendation
  end

  def create_ckasset(asset_type = Ckeditor::AttachmentFile, file_name = "test_pic.png")
    asset = asset_type.new
    asset.data = fixture_file_upload(File.join("files", file_name), "image/png")
    asset.organization = programs(:org_primary)
    asset.login_required = true
    asset.save!
    asset
  end

  # create a dummy membership request
  def create_membership_request(options = {}, answers = {}, params = {})
    program = options[:program] || programs(:albers)
    admin = options.delete(:admin)
    no_save = options.delete(:no_save)

    options.reverse_merge!(roles: [RoleConstants::STUDENT_NAME])
    member = options[:member]
    member ||= members(:f_student) if options[:roles].include?(RoleConstants::MENTOR_NAME)
    member ||= members(:f_mentor) if options[:roles].include?(RoleConstants::STUDENT_NAME)
    member ||= members(:f_admin)
    options.reverse_merge!(
      first_name: member.first_name,
      last_name: member.last_name,
      email: member.email,
      program: program)
    member.update_answers(program.organization.profile_questions, answers, nil, false, false, params)
    req = MembershipRequest.create_from_params(options.delete(:program), options, member, params)
    req.response_text = options[:response_text] || "Sorry" if req.rejected?
    req.admin = (admin || users(:f_admin)) unless req.pending?
    req.save! unless no_save
    req
  end

  def create_program_invitation(options = {})
    program = options[:program] || programs(:albers)
    ProgramInvitation.create!(
      program: program,
      sent_to: options[:email] || "invite@example.com",
      user: program.admin_users.first,
      role_names: options[:role_names] || [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME],
      role_type: options[:role_type] || ProgramInvitation::RoleType::ASSIGN_ROLE
    )
  end

  # This method is to create user favorite
  def create_favorite(options ={})
    UserFavorite.create(:user => options[:user] || users(:f_student), :favorite => options[:favorite] || users(:f_mentor), :note => options[:note])
  end

  def create_mentoring_model(options = {})
    MentoringModel.create!({
      title: "Homeland",
      description: "Carrie Mathison",
      default: false,
      program_id: programs(:albers).id,
      mentoring_period: Program::DEFAULT_MENTORING_PERIOD,
      skip_default_permissions: true,
      mentoring_model_type: MentoringModel::Type::BASE
    }.merge(options))
  end

  def create_mentoring_model_goal(options = {})
    options[:template_version] ||= 1 if options[:from_template]
    options.reverse_merge!(
      title: "Awesome Title",
      description: "Awesome Description",
      group_id: groups(:mygroup).id
    )
    MentoringModel::Goal.create! options
  end

  def create_mentoring_model_goal_activity(goal, options={})
    goal_activity = goal.goal_activities.new
    goal_activity.message = options[:message] || "This is a goal activity message"
    goal_activity.progress_value = options[:progress_value]
    goal_activity.connection_membership = goal.group.memberships.first
    goal_activity.member_id = goal.group.memberships.first.user.member_id
    goal_activity.save!
    goal_activity
  end

  def create_coaching_goal(options = {})
    coaching_goal = CoachingGoal.new({
      :title => options[:title] || "Awesome Title",
      :description => options[:description] || "Awesome Description",
      :group_id => options[:group_id] || groups(:mygroup).id,
      :due_date => options[:due_date],
      :connection_membership_id => options[:connection_membership_id]
    })
    coaching_goal.creator = options[:creator] || groups(:mygroup).mentors.first
    coaching_goal.save!
    coaching_goal
  end

  def create_coaching_goal_activity(coaching_goal, options={})
    coaching_goal = CoachingGoalActivity.new({
      :coaching_goal_id => coaching_goal.id,
      :progress_value => options[:progress_value],
      :message => options[:message]
    })
    coaching_goal.initiator = options[:initiator] || groups(:mygroup).mentors.first
    coaching_goal.save!
    coaching_goal
  end

  def create_project_request(group, student_user)
    student_role_id = group.program.get_role(RoleConstants::STUDENT_NAME).id
    group.project_requests.create!(program_id: group.program_id, sender_id: student_user.id, sender_role_id: student_role_id, status: AbstractRequest::Status::NOT_ANSWERED, message: "Frank Underwood")
  end

  def create_groups_report_view_column(program, column_key)
    program.report_view_columns.create!(
      :report_type => ReportViewColumn::ReportType::GROUPS_REPORT,
      :column_key => column_key
    )
  end

  def create_report_metric(options={})
    program = programs(:albers)
    options[:abstract_view_id] = options[:abstract_view_id] || program.abstract_views.first.id
    section = Report::Section.find(options.delete(:section_id) || program.report_sections.first.id)
    options[:title] = options[:title] || "My Metric"
    options[:description] = options[:description] || "description for metric"
    new_metric = section.metrics.build(options)
    new_metric.save!
    return new_metric
  end

  def create_alert_for_metric(metric, options)
    options[:operator] = options[:operator] || Report::Alert::OperatorType::LESS_THAN
    options[:target] = options[:target] || 1
    options[:description] = options[:description] || "description for alert"
    alert_params = options.pick(:operator, :target, :description, :filter_params)
    alert_params.merge!({filter_params: nil}) if alert_params[:filter_params].blank?
    new_alert = metric.alerts.build(alert_params)
    new_alert.save!
    return new_alert
  end

  def create_mentor_recommendation(sender, receiver, program)
    recommendation = MentorRecommendation.new
    recommendation.sender = sender
    recommendation.receiver = receiver
    recommendation.program = program
    recommendation.status = MentorRecommendation::Status::PUBLISHED
    recommendation.save!
    return recommendation
  end

  def create_task_comment(task, options = {})
    comment = task.comments.new
    comment.sender  = options[:sender] || task.group.members.first.member
    comment.content = options[:content] || "Comment Content"
    comment.program = options[:program] || task.group.program
    comment.notify  = options[:notify] || false
    comment.attachment = options[:attachment]
    comment.save!
    return comment
  end

  def create_task_checkin(task, options = {})
    checkin = task.checkins.new
    checkin.title = task.title
    checkin.user = task.user
    checkin.program = options[:program] || programs(:albers)
    checkin.comment = options[:comment] || "Check in comment"
    checkin.group = options[:group] || groups(:mygroup)
    checkin.date = options[:date] || DateTime.new(2001,1,1)
    hours = options[:hours] || 1
    minutes = options[:minutes] || 0
    checkin.duration = options[:duration] || hours*60 + minutes
    checkin.save!
    return checkin
  end

  def create_meeting_checkin(member_meeting, options = {})
    checkin = member_meeting.checkins.new
    member  = options[:member] || member_meeting.member
    meeting = options[:meeting] || member_meeting.meeting
    group = options[:group] || meeting.group
    program = options[:program] || meeting.program
    checkin.title = meeting.topic
    checkin.comment = options[:comment] || meeting.description
    checkin.date = options[:occurrence] || meeting.occurrences.first
    checkin.duration = options[:duration] || meeting.schedule.duration
    checkin.user = options[:user] || member.user_in_program(program.id)
    checkin.program = program
    checkin.group = group
    checkin.save!
    return checkin
  end

  def create_connection_membership(group, user, options = {})
    status = options[:status] || Connection::Membership::Status::ACTIVE;
    role = options[:role] ||  RoleConstants::STUDENT_NAME
    membership = Connection::Membership.create!(
        :group => group,
        :user => user,
        :status => status,
        :role_id => user.roles.find_by(name: role).id
    )
  end

  def create_app_document(options = {})
    doc = ChronusDocs::AppDocument.create!(options.reverse_merge({
      title: "Chronus_Mentor_Connections_API_V2",
      description: "This is Chronus API Doc"
    }))
    return doc
  end

  def create_o_auth_credential(options = {})
    access_token = options[:access_token] || "access_token_sample"
    refresh_token = options[:refresh_token] || "refresh_token_sample"
    type = options[:type] || "GoogleOAuthCredential"
    ref_obj = options[:ref_obj] || members(:f_mentor)
    ref_obj_type = ref_obj.is_a?(AbstractProgram) ? AbstractProgram.name : Member.name
    (options[:type] || GoogleOAuthCredential).create!(access_token: access_token, refresh_token: refresh_token, ref_obj_type: ref_obj_type, ref_obj_id: ref_obj.id)
  end

  def get_free_calendar_slots_for_member(date = Date.current, start_time_symbol = :start, end_time_symbol = :end)
    # 12am - 2am, 4am - 6.30am, 2pm - 6.30pm
    date_beginning_in_utc = date.beginning_of_day.utc
    [{start_time_symbol => date_beginning_in_utc, end_time_symbol => date_beginning_in_utc + 2.hours}, {start_time_symbol => date_beginning_in_utc + 4.hours, end_time_symbol => date_beginning_in_utc + (6.5).hours}, {start_time_symbol => date_beginning_in_utc + 14.hours, end_time_symbol => date_beginning_in_utc + (18.5).hours}]
  end

  def at(time, &block)
    Timecop.freeze(dt(time)) do
      delay_jobs(&block)
    end
  end

  def delay_jobs(&block)
    begin
      Delayed::Worker.delay_jobs = true
      block.call
    ensure
      Delayed::Worker.delay_jobs = false
    end
  end

  def dt(time)
    DateTime.parse(time)
  end

  ##############################################################################
  # Assertion related helpers
  #############################################################################

  # Check if two arrays contain the same objects irrespective of their position.
  #
  def assert_equal_unordered(a,b)
    array_diff = (a - b) + (b - a)
    assert(array_diff.length == 0,
      "Arrays not equal:\n" +
        "expected [#{a.join(', ')}]\n" +
        " but was [#{b.join(', ')}]")
  end

  def assert_equal_unordered_objects(a,b)
    a_ids = a.collect(&:id)
    a_classes = a.collect(&:class).collect(&:to_s)
    b_ids = b.collect(&:id)
    b_classes = b.collect(&:class).collect(&:to_s)

    ids_diff = (a_ids - b_ids) + (b_ids - a_ids)
    assert(ids_diff.length == 0,
      "Arrays not equal:\n" +
        "expected ids [#{a_ids.join(', ')}]\n" +
        " but was [#{b_ids.join(', ')}]")

    classes_diff = (a_classes - b_classes) + (b_classes - a_classes)
    assert(classes_diff.length == 0,
      "Arrays not equal:\n" +
      "expected classes [#{a_classes.join(', ')}]\n" +
        " but was [#{b_classes.join(', ')}]")
  end

  def assert_floats_equal(a,b, delta = 0.00001)
    assert_in_delta a, b
  end

  def assert_equal_hash(expected, got)
    assert_dynamic_expected_nil_or_equal params_to_h(expected).with_indifferent_access, params_to_h(got).with_indifferent_access
  end

  def params_to_h(params)
    params.is_a?(ActionController::Parameters) ? params.permit!.to_h : params
  end

  def assert_equal_arrays_hash(expected, got)
    assert_arrays_equal expected.collect(&:with_indifferent_access), got.collect(&:with_indifferent_access)
  end

  def assert_mentoring_slots(expected, got)
    assert_equal expected.size, got.size

    expected.each_with_index do |value, index|
      assert_equal value.with_indifferent_access, got[index].with_indifferent_access
    end
  end

  def assert_content_type(expected, got, message = nil)
    assert_equal "text/csv", got.split(';').first.to_s
  end

  def assert_gem_version(gem_name, version, msg = nil)
    expected = "gem #{gem_name} version #{version}"
    actual = "gem #{gem_name} version #{get_gem_version(gem_name)}"
    assert_equal(expected, actual, msg)
  end

  def get_gem_version(gem_name)
    str = `bundle show #{gem_name}`
    str.chomp.match(/#{gem_name}-(.*)/)[1]
  end

  def check_group_state_change_unit(group, group_state_change, from_status)
    assert_equal group.id, group_state_change.reload.group_id
    assert_equal from_status.to_s, group_state_change.from_state.to_s
    assert_equal group.status.to_s, group_state_change.to_state
    assert_equal (Time.now.utc.to_i/1.day.to_i), group_state_change.date_id
  end

  def assert_blank(arg)
    assert arg.blank?
  end

  # Check if two arrays contain the same objects, in the same order.
  #
  def assert_arrays_equal(a,b)
    assert a.size == b.size, "Array sizes differ: Expected #{a.size}, Got #{b.size}"
    assert_equal a, b, "Arrays do not match: #{((a - b) + (b - a)).inspect}"
  end

  def assert_select_helper_function(expected_match, actual_content, options = {})
    doc = Nokogiri::HTML(actual_content)
    assert_select doc.root, expected_match, options
  end

  def assert_select_helper_function_block(expected_match, actual_content, options = {}, &block)
    doc = Nokogiri::HTML(actual_content)
    assert_select doc.root, expected_match, options do
      yield
    end
  end

  # Asserts that an error is raised on the given field and with the given
  # message (optional) by the given block
  def assert_raise_error_on_field(
      exception_class,
      field,
      expected_message = nil,
      options = {},
      &block)

    error_raised = nil
    error_info = assert_raise exception_class, "Did not get exception for field #{field}" do
      # Execute the block in a rescue block so that we can re-raise the exception
      # if required.
      begin
        yield
      rescue => error_raised
        raise error_raised
      end
    end

    # Extract the field name and error message from the return value
    # Eg., Process "Validation failed: Coach can't be blank, Area is not given"
    # to get ['coach', 'can't be blank'], ['area', 'is not given'] pairs.
    #
    error_info.message.match(/.*: (.*)/)

    # Panic if no field errors.
    assert_not_nil $1

    field_errors = $1.split(", ")

    match_found = false
    wrong_message = false
    error_object_class = error_raised.record.class

    field_errors.each do |error_entry|
      # Skip to next error if not matched.
      field_as_displayed = error_object_class.human_attribute_name(field)
      next unless error_entry.match(/(#{field_as_displayed}) (.*)/)

      if field_as_displayed.downcase == $1.downcase
        # First condition matched
        match_found = true

        # See if second condition also matches, if given
        if !expected_message.blank? && expected_message != $2
          match_found = false
          wrong_message = $2
        end
      end
    end

    if !match_found
      if wrong_message
        assert false, "Exception message on field #{field} did not match: " +
          "Expected '#{expected_message}', Got '#{wrong_message}'"
      else
        assert false, "Expected to raise exception on field #{field}, but nothing raised"
      end
    end

    raise error_raised if options[:cascade]
  end

  # A brute force approach for asserting multiple errors on fields. Yields the block
  # once per each error expectation.
  #
  # ==== Other alernative approach:
  # <i>assert_raise_error_on_field</i> has :cascade option too, which when
  # specified, will re-raise the exception after assertion.
  #
  # So, for asserting say, 'n' exceptions, nest the assert_raise_error_on_field
  # calls, passing :cascade => true to all calls except for the top most one.
  #
  def assert_multiple_errors(expected_errors, &block)
    expected_errors.each do |error_info|
      exception_klass = error_info[:exception] || ActiveRecord::RecordInvalid
      assert_raise_error_on_field exception_klass, error_info[:field], error_info[:message] do
        yield
      end
    end
  end

 # Checks whether the given tab is selected.
  def assert_tab(label)
    assert @controller.tab_info[label].active, "Tab '#{label}' is not selected"
  end

 # Checks whether the given tab is not selected.
  def assert_not_tab(label)
    assert_false @controller.tab_info[label].active, "Tab '#{label}' is selected"
  end

  # Asserts that an Authorization::PermissionDenied exception is thrown by
  # base_auth
  #
  def assert_permission_denied(&block)
    assert_raise Authorization::PermissionDenied do
      yield
    end
  end

  def assert_record_not_found(&block)
    assert_raise ActiveRecord::RecordNotFound do
      yield
    end
  end

  # Assert the title of the page
  def assert_page_title(string)
    assert_select "div#title_box" do
      assert_select "div#page_heading", :text => /#{string}/
    end
  end

  def assert_false(boolean, message = nil)
    if message
      assert(!boolean, message)
    else
      assert(!boolean)
    end
  end

  def assert_match_with_squeeze(regex, text)
    assert_match regex, text.gsub("\n", " ").squeeze(" ")
  end

  def assert_not_match(re, value, escape = false)
    re = Regexp.new(Regexp.escape(re)) if escape
    assert !(value =~ re), "Got #{value} that matched #{re}"
  end

  def assert_time_is_equal_with_delta(expected, actual, delta = 3)
    # Allow for some time lag - the lag being 'delta' seconds here
    if (expected - actual).abs < delta
      true
    else
      flunk "Expected #{actual} to be #{expected} (+/- #{delta})"
    end
  end

  def assert_time_string_equal(expected_time, actual_time)
    assert_equal expected_time.strftime("%B %d, %Y at %I:%M %p"), actual_time.strftime("%B %d, %Y at %I:%M %p")
  end

  # For the following two asserts, we cannot use assert_redirected_to
  # because request params are not setup properly by the
  # test process and the redirect URL is not proper.
  # This is how ssl_requirement_test tests for http redirects.

  # Assert that we got a redirect to the https version of the page
  # Note that the Redirect URL cannot be reliably compared here
  def assert_https_redirect
    assert_response :redirect
    # If assert_match fails, the test will stop here
    assert_match %r{^https://}, @response.headers['Location']
    # assert_match succeeded. Return true
    true
  end

  # Assert that we got a redirect to the http version of the page
  # Note that the Redirect URL cannot be reliably compared here
  def assert_http_redirect
    assert_response :redirect
    # If assert_match fails, the test will stop here
    assert_match %r{^http://}, @response.headers['Location']
    # assert_match succeeded. Return true
    true
  end

  def assert_emails(count = 1, &block)
    assert_difference 'ActionMailer::Base.deliveries.size', count do
      yield
    end
  end

  def assert_pending_notifications(count = 1, &block)
    assert_difference 'PendingNotification.count', count do
      yield
    end
  end

  def assert_no_emails(&block)
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      yield
    end
  end

  # Runs assert_difference with a number of conditions and varying difference counts.
  #
  # USAGE: assert_differences([['Model1.count', 2], ['Model2.count', 3]])
  def assert_differences(expression_array, &block)
    bindings = block.send(:binding)
    before = expression_array.map { |expr| eval(expr[0], bindings) }
    yield
    expression_array.each_with_index do |pair, i|
      expr, difference = pair
      assert_equal(before[i] + difference, eval(expr, bindings), "#{expr} didn't change by #{difference}")
    end
  end

  # Asserts that there's a flash box with the given text in the page
  def assert_flash_in_page(text)
    assert_match text, flash[:notice]
  end

  def assert_flash_in_webpage(text)
    assert_match text, flash[:notice]
  end

  # Asserts that there's no flash box in the page
  def assert_no_flash_in_page
    assert_nil flash[:notice]
  end

  def assert_no_flash_in_webpage
    assert_nil flash[:notice]
  end

  def assert_dynamic_expected_nil_or_equal(expected, actual)
    if expected.nil?
      assert_nil actual
    else
      assert_equal expected, actual
    end
  end

  # Assert the absence of a html node - right now takes only a selector
  def assert_no_select(selector, options={})
    assert_select selector, options.merge({ :count => 0 })
  end

  def assert_ckeditor_rendered
    assert_match(/ckeditor_config.*.js/, @response.body)
  end

  def assert_ckeditor_not_rendered
    assert_no_match(/ckeditor_config.*.js/, @response.body)
  end

  def assert_gtac_rendered
    assert_match /pageTracker/, @response.body
  end

  def assert_inner_tab_selected(tab_name)
    assert_select 'div.inner_tabs' do
      assert_select 'li.active', :text => tab_name
    end
  end

  def assert_no_inner_tabs
    assert_select 'div.inner_tabs', :count => 0
  end

  def assert_instance_variables(name_expected_value_map, assert_method = :assert_equal)
    name_expected_value_map.keys.each do |name|
      instance_variable_set :"@#{name}", nil
    end
    yield
    name_expected_value_map.each do |name, expected_value|
      send(assert_method, expected_value, instance_variable_get(:"@#{name}"))
    end
  end

  ##############################################################################
  # HTTP Helpers
  #############################################################################
  # Simulates a HTTPS request. Use this to test HTTPS actions. If http get is
  # used for a https action, you'll be redirected to https version of
  # the URL
  def https_request(method, *args)
    @request.env['HTTPS'] = 'on'
    @request.env['SERVER_PORT'] = 443
    send(method, *args)
    @request.env['SERVER_PORT'] = 80
    @request.env['HTTPS'] = 'off'
  end

  # Simulates a HTTPS get. Use this to test HTTPS actions. If http get is
  # used for a https action, you'll be redirected to https version of
  # the URL
  def https_get(*args)
    https_request(:get, *args)
  end

  # Simulates a HTTPS post. Use this to test HTTPS actions. If http get is
  # used for a https action, you'll be redirected to https version of
  # the URL
  def https_post(*args)
    https_request(:post, *args)
  end

  # Simulates a HTTPS put. Use this to test HTTPS actions. If http get is
  # used for a https action, you'll be redirected to https version of
  # the URL
  def https_put(*args)
    https_request(:put, *args)
  end

  # Simulates a HTTPS patch. Use this to test HTTPS actions. 
  def https_patch(*args)
    https_request(:patch, *args)
  end

  # Simulates a HTTPS delete. Use this to test HTTPS actions. If http get is
  # used for a https action, you'll be redirected to https version of
  # the URL
  def https_delete(*args)
    https_request(:delete, *args)
  end

  # Simulates a HTTPS XML request. Use this to test HTTPS actions. If http get is
  # used for a https action, you'll be redirected to https version of
  # the URL
  def https_xhr(*args)
    https_request(:xhr, *args)
  end

  ##############################################################################
  # Mock/Stub Helpers
  #############################################################################


  def stub_matching_index
    return if @skip_stubbing_match_index
    %w(
        perform_full_index_and_refresh
        perform_program_delta_index_and_refresh
        perform_users_delta_index_and_refresh
        remove_user
        remove_mentor_later
        remove_student_later
    ).each do |method|
      Matching.stubs(method)
    end
  end

  def stub_parallel
    require Rails.root.to_s + '/test/lib/parallel_overrides'
  end

  def stub_push_notifier
    Push::NotificationMapper.instance.send(:init_responders)
    PushNotifier.any_instance.stubs(:notify).returns(true)
  end

  def stub_current_program(program)
    Object.any_instance.stubs(:current_program).returns(program)
  end

  def stub_current_user(user)
    Object.any_instance.stubs(:current_user).returns(user)
  end

  def stub_busy_slots_for_members(member_ids, date = Date.current)
    result_hash = {}
    member_ids.each do |id|
      start_time_in_utc = date.beginning_of_day.utc + (id % 30).minutes
      result_hash[id] = {error_occured: false, busy_slots: [{start_time: start_time_in_utc, end_time: start_time_in_utc + 15.minutes}, {start_time: start_time_in_utc + 2.hours, end_time: start_time_in_utc + 3.hours}, {start_time: start_time_in_utc + 8.hours, end_time: start_time_in_utc + (8.75).hours}], error_code: nil, error_message: nil}
    end
    CalendarQuery.stubs(:get_busy_slots_for_members).returns(result_hash)
  end

  def stub_paperclip_size(size)
    File.stubs(:size).returns(size)
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(size)
    Paperclip::Tempfile.any_instance.stubs(:size).returns(size)
  end

  def mock_soap_call(hash = nil, options = nil)
    options = options || {"wsdl_url" => "abc", "method_name" => "test_method"}
    hash = hash || {"valid"=> "false", "error" => "Failure"}
    soap = mock
    driver_mock = mock

    require 'soap/wsdlDriver' # Rails3L
    SOAP::WSDLDriverFactory.expects(:new).at_least(0).with(options["wsdl_url"]).returns(soap)
    soap.expects(:create_rpc_driver).at_least(0).returns(driver_mock)
    driver_mock.expects(options["method_name"].to_sym).at_least(0).returns(hash.to_json)
  end

  def mock_api_sso_call(res_hash, url, options)
    response = mock
    response_body = mock

    HTTPClient.expects(:post).at_least(1).with(url, options).returns(response)
    response.expects(:body).at_least(1).returns(res_hash["content"])
    response.expects(:status).at_least(1).returns(res_hash["status"])
  end

  def mock_ldap_call(res=nil, options=nil)
    ldap = mock
    message = mock
    cert_store = mock
    if options["cert_store"]
      OpenSSL::X509::Store.expects(:new).returns(cert_store)
      cert_store.expects(:add_cert)
    end
    Net::LDAP.expects(:new).with({
          :host => options["host"],
          :port => options["port"],
          :auth => options["binding_auth"],
          :encryption =>  (:simple_tls if options["secure"]),
          :cert_store => (cert_store if options["cert_store"])
        }.reject{ |k,v| v.nil? }).returns(ldap)
    ldap.expects(:bind_as).returns(res["bind"])
    ldap.expects(:get_operation_result).at_least(res["bind"] ? 0 : 1).returns(message)
    message.expects(:message).at_least(res["bind"] ? 0 : 1).returns(res["operation_result"])
  end

  def temp_form_object(klass, options = {})
    object = Object.new
    object.extend(ActionView::Helpers::FormHelper)
    object.extend(ActionView::Helpers::FormOptionsHelper)
    if options[:custom_object].present?
      return SimpleForm::FormBuilder.new(options[:custom_object], nil, object, {})
    else
      return SimpleForm::FormBuilder.new(klass, klass.new, object, {})
    end
  end

  def get_cookie(cookie_name)
    @response.cookies[cookie_name.to_s]
  end

  def setup_cookie
    ActionDispatch::Cookies::CookieJar.new(ActionController::TestRequest.create(self.class))
  end

  # Used to redefine the constants during the execution of a block and then reset it.
  #   name(symbol) : Name of the constant to be redefined.
  #   value: New value for the cosntant - <name>.
  def modify_const(name, value, namespace = nil, &block)
    namespace ||= Object
    redefine_const(name, value, namespace)

    begin
      yield
    ensure
      reset_const(name, namespace)
    end
  end

  # To redefine constant of a particular class during execution of block and reset
  def change_const_of(klass, name, value, &block)
    if klass.const_defined?(name)
      original = klass.const_get(name)
      klass.send(:remove_const, name)
    end
    klass.const_set(name, value)

    begin
      yield
    ensure
      klass.send(:remove_const, name) if klass.const_defined?(name)
      klass.const_set(name, original) if original
    end
  end

  def mock_now(time)
    Time.stubs('now').returns(time)
    assert_equal time, Time.now
  end

  ###################
  # Capybara JS Stubs
  ###################

  def stub_view_flow_for_content_tag(&block) # When we use content_for in helper, Rails internally expects @view_flow object. In helper test we have to set it manually
    @view_flow = ActionView::OutputFlow.new
    yield
  ensure
    @view_flow = nil
  end

  def group_forum_setup
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    mentoring_model.allow_forum = true
    mentoring_model.allow_messaging = false
    mentoring_model.save!

    @group = groups(:mygroup)
    @group.update_attribute(:mentoring_model_id, mentoring_model.id)
    @group.create_group_forum
    @forum = @group.forum
  end

  def enable_membership_request!(program_or_organization)
    unless program_or_organization.is_a? Program
      program_or_organization = program_or_organization.programs.first
    end
    role_to_join = program_or_organization.roles_without_admin_role.first
    role_to_join.membership_request = true
    role_to_join.save!
    program_or_organization.reload
  end

  def disable_membership_request!(program_or_organization)
    if program_or_organization.is_a? Program 
      roles = program_or_organization.roles_without_admin_role
    elsif program_or_organization.is_a? Organization
      ids = program_or_organization.programs.pluck(:id)
      roles = Role.where("program_id in (?)", ids).non_administrative
    end
    roles.each do |role|
      role.membership_request = role.join_directly = role.join_directly_only_with_sso = role.eligibility_rules = false
      role.save!
    end
    program_or_organization.reload
  end

  def get_calendar_event_resource(options = {})
    # modify the hash whenever needed to include other properties

    event_hash = {
      "kind": "calendar#event",
      "id": options[:id] || "caledar_event_id",
      "summary": "Test Meeting",
      "description": "This is test meeting",
      "location": "Hyderabad",
      "attendees": get_calendar_event_attendees,
      "recurring_event_id": options[:recurring_event_id]
    }

    event = OpenStruct.new event_hash

    return event
  end

  def assert_xhr_redirect(redirect_path)
    assert_equal "window.location.href = \"#{redirect_path}\";", @response.body
  end

  def assert_open_auth_redirect(organization, session_id)
    client_id = organization.security_setting.linkedin_token
    encoded_state = Base64.urlsafe_encode64(session_id)
    redirect_uri = oauth_callback_session_url(host: DEFAULT_HOST_NAME, subdomain: SECURE_SUBDOMAIN, protocol: "http", organization_level: true)
    assert_redirected_to "https://www.linkedin.com/oauth/v2/authorization?client_id=#{client_id}&redirect_uri=#{CGI.escape(redirect_uri)}&response_type=code&scope=r_basicprofile+r_emailaddress&state=#{CGI.escape(encoded_state)}"
  end

  def create_saml_auth(organization, type_options = {}, config_options = {})
    options =
      if type_options[:slo]
        {
          "idp_sso_target_url" => "https://saml.chronus.com",
          "idp_cert_fingerprint"=>"9f0898770d9f0948c45bf5d6db55cb037c3b280c",
          "xmlsec_privatekey"=>"-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQCaKH4lucss8UPp\nIplLbXxloTbgJMsqHgCry4DWLW3+OEUW0mUWKFJ88ZpY+kk0gvAVXY2kDo/KlhbJ\n8jbygAqW3TKpQ+AtKiDu930Bx9D6sgWPPdl1XCGhWExuG2exnjruMmd2ixf/4EFz\nGdj5GGwlw5TZYPtYlJT0ou1qkr7X+Wxl0sddrTr+vmUezKYCSrq8ARoe8toBJddN\nm2P2HvczuE2e2I83d00wHButLG2miNhHHuiizR07p5eLMLbSt5l6LmM+KDFPD/3x\n77I0MSLAoPEiCyEB1q6dcqamRSJuiya931HflitOSyC8AEP9bZ67tf8EmirLwKa0\nVfhqBtw/AgMBAAECggEAaiwzXaZN0eFFJX9n1vRMNe7Hza5potNRIQEi9eAKHooA\nw4wahR02WslHxbpzys/XrM9nKzPAQwYGIgZJY9Fd+bPVHZEbB+A5GHypwx0syEzt\n2U7+w361xtr6oOcNDt7stXtPmOyJlfiM+0o1DrKMYaIHlYPe+I403RyNqdXxzOrx\n1AZ4FOUYyTFlNeEQj9nrQpRzZb0XdGYp59T8tAYO/Lrx1TqIHAJ2oCBU3qbJCte9\nvl6Gu/keNPf6dafXoZnYutH0Q/Ktr3XP/4VJk8wu8Pk3hurUkUk+TGGtwgG/4And\nPA6Rc7ekvcnzqh5S3TA3LmFNl39kCukXzuvFlCTsuQKBgQDKlp5TvnqdeZxTqPYF\ni/eo4njB3w2+Agj0fqPSw7n8ZCdCTgq4A+UAzpiQ9+ckBV3BoByJqsTP7RziYwp6\nLk6p1QmpNB5arG51qsDobkMvO23UugMylVVXpL8vJi+UTjt4UGC3zmDzNIiInVux\n9S3RCQ6vV8OrczCxErWegrOWTQKBgQDCzSffEwiuX90jgX9n9kST/l2hwib+2OfA\noxBK23prHDDJtJDaDRvk2++gPksXZ167H4Sy1oZ7sz8AGo2Cg5uzb+IP3lDziAoj\nGxQgFVszE1ujNW6yyTzBUnuicpgd2KhPbD4CsKRubqv2PWfiWc/35xczfnYMZzSo\nyVX1mIVauwKBgQCwDOPZ8pWrc5seOJ5Tg6bc5LH8CFJw5GPT1JmY9u4RHxfezuMR\ntpCzetWqZURAUUmAkhs6p2QRLQUE1vyr4MILZE7Y86nNMjtrlc++LNPFn+d6DYvp\n0UwwtcJOvuhqAPI9Q9xI3tfxgZ2E2vpsU5xVI4HXbnVj8N5HgvLBpONboQKBgQCc\nOERqW+xRUuWYDMjsyY0zlgDmsTnulGo+jUaKkbp53VCu4ZRsmait/0cLHgnAShCp\nRdx4Qxv0Zcn3PlQPv5WE8Au9qA8JTia7AoNAO4A41KRfnYEZ9dI4QvqNSxL8lHxd\nvTN5mskzGqPjRFlkJ5xldTig/iCTT8zmMxgxbdA78wKBgQCj21qLCQhPzi544FVk\nDMKJzyP/MOKGSQUGMbHerLxnosVfr0qWMCktH8JH/ZyQ5TvLJuDWlmmns3FYTShn\nDsyZS9H1VezTSPrMTWzYaqVrAqwOlnjCjzqT9+tvTk27czFYxFwmunZCayBQ3UjH\nULaPZsOofhRoq17nLWGwP20AbQ==\n-----END PRIVATE KEY-----\n",
          "xmlsec_certificate"=>"-----BEGIN CERTIFICATE-----\nMIIDpjCCAo4CCQCK0hY5T/4PLzANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMC\nVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNV\nBAoTDENocm9udXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNo\ncm9udXMuY29tMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wHhcNMTUx\nMDE5MDkwMjA4WhcNMjUxMDE2MDkwMjA4WjCBlDELMAkGA1UEBhMCVVMxEDAOBgNV\nBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxFTATBgNVBAoTDENocm9u\ndXMgQ29ycDEPMA0GA1UECxMGTWVudG9yMRYwFAYDVQQDFA0qLmNocm9udXMuY29t\nMR4wHAYJKoZIhvcNAQkBFg9vcHNAY2hyb251cy5jb20wggEiMA0GCSqGSIb3DQEB\nAQUAA4IBDwAwggEKAoIBAQCaKH4lucss8UPpIplLbXxloTbgJMsqHgCry4DWLW3+\nOEUW0mUWKFJ88ZpY+kk0gvAVXY2kDo/KlhbJ8jbygAqW3TKpQ+AtKiDu930Bx9D6\nsgWPPdl1XCGhWExuG2exnjruMmd2ixf/4EFzGdj5GGwlw5TZYPtYlJT0ou1qkr7X\n+Wxl0sddrTr+vmUezKYCSrq8ARoe8toBJddNm2P2HvczuE2e2I83d00wHButLG2m\niNhHHuiizR07p5eLMLbSt5l6LmM+KDFPD/3x77I0MSLAoPEiCyEB1q6dcqamRSJu\niya931HflitOSyC8AEP9bZ67tf8EmirLwKa0VfhqBtw/AgMBAAEwDQYJKoZIhvcN\nAQEFBQADggEBAHTVfLDRzT7Ey15treXJ6jfT9dpaglCwgAhfeIXg0bZ10KXP3JC6\nK5KAMxGiYPIDiC1adCnAxdPwj25ThYNmWb3K7V5yIn9XlVMT3kGmkQHyI0+5MnfK\nTvnFznsUeC05fyw50OHH1jKwFzRjjA6yp5BhAn5P6AfPPs9fmtSfstO3EXzYqG2R\ngTydizP2+tIpISqASVo6D788fK8yW5LbKsfUkq3kLzSb9cfPrfYDPgen3YB2sQ4n\nX4c0smFTzPKR/Pe5WbQvxJWf0kpzg/uWK4kzMfgPwzE2FtVC4yqlr80f9xHXh/QH\n9nut8QqnVda7QBhAQlOcghgFhxbO0UjE6hc=\n-----END CERTIFICATE-----\n",
          "xmlsec_privatekey_pwd"=>"cTfje8CQdD0L3HPToHhm7A",
          "idp_slo_target_url"=>"https://saml.chronus.com/slo"
        }
      elsif type_options[:name_parser]
        {
          "idp_sso_target_url" => "https://saml.chronus.com",
          "idp_cert_fingerprint" => "17fba32a30806b5536ceb4861611a31b95660272",
          "xmlsec_certificate" => "-----BEGIN CERTIFICATE-----\nMIIEqjCCA5KgAwIBAgIJALr7nVjhA4FNMA0GCSqGSIb3DQEBBQUAMIGUMQswCQYD\nVQQGEwJVUzEQMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEV\nMBMGA1UEChMMQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMU\nDSouY2hyb251cy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTAe\nFw0xMzA5MjMxNDIyMzBaFw0xNDA5MjMxNDIyMzBaMIGUMQswCQYDVQQGEwJVUzEQ\nMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEVMBMGA1UEChMM\nQ2hyb251cyBDb3JwMQ8wDQYDVQQLEwZNZW50b3IxFjAUBgNVBAMUDSouY2hyb251\ncy5jb20xHjAcBgkqhkiG9w0BCQEWD29wc0BjaHJvbnVzLmNvbTCCASIwDQYJKoZI\nhvcNAQEBBQADggEPADCCAQoCggEBAO9oi6esxom5f5HRBmD/csqNqtLK9pxJl30H\n0/DDsMnDspAxUDE9d7MXyuIBQNMnDYX1ct0EDIujfmvsqzdbXWn/qWwJPBhw87C6\nVyOyct2Dtu3paMDWypduzelouPz6nGn/RNCr+xeJyjMhxg9wKGAxYcyu/4Dgun/Q\nHPKNNx15mqgkFSaacFIKc/HSG6MBCuyO2A+sJ43nVcuY6fgyCabVnwfZ+L/8zthP\nGthDl6MywgBJUXN/Ct2FDky/SUqUeyCBtaYYZC9rMD181Hn6lbU/EqJFT0JYhr2f\nFkHu5owwzIrI6ISbuuLFL6+BXjQ45CwYsXwMofmbiXEh+Z3rgdECAwEAAaOB/DCB\n+TAdBgNVHQ4EFgQUUiyvww7fh/IbKEQqst6Kts8sy3EwgckGA1UdIwSBwTCBvoAU\nUiyvww7fh/IbKEQqst6Kts8sy3GhgZqkgZcwgZQxCzAJBgNVBAYTAlVTMRAwDgYD\nVQQIEwdBcml6b25hMRMwEQYDVQQHEwpTY290dHNkYWxlMRUwEwYDVQQKEwxDaHJv\nbnVzIENvcnAxDzANBgNVBAsTBk1lbnRvcjEWMBQGA1UEAxQNKi5jaHJvbnVzLmNv\nbTEeMBwGCSqGSIb3DQEJARYPb3BzQGNocm9udXMuY29tggkAuvudWOEDgU0wDAYD\nVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOCAQEAV+KpY7DyAGFRB+mGV9tmBDT/\nePqtH0HnUpjrKtF1RU9kHPNvnyxs2Si8LHFyomp5PM0Nc+WqCDKl9oSY7jvxvKfI\nxqoCwoWi+aMR2hVkKkcBWps8FS75QOkakh8BwIVNAiuT0GY0OnB7IF5k2EaTfPLM\niyJZIU3ubM4pg+CL1dk3TUiKvj9BetD3A+7gQOXVIvGKkQBLR+//WCMBAgBc6s9t\nHJDyPq2gNjzCArAfaHmt67BqV21U5px5QfNKsYmRbSwYF+j8lww8xHwcedhHOTn6\nxHIVOvUGA6Gd/vsQahZ+Pod9rbY20y/Ln4kdR55gv3WXVzYfqxvEe3B52edX+w==\n-----END CERTIFICATE-----\n",
          "xmlsec_privatekey" => "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA72iLp6zGibl/kdEGYP9yyo2q0sr2nEmXfQfT8MOwycOykDFQ\nMT13sxfK4gFA0ycNhfVy3QQMi6N+a+yrN1tdaf+pbAk8GHDzsLpXI7Jy3YO27elo\nwNbKl27N6Wi4/Pqcaf9E0Kv7F4nKMyHGD3AoYDFhzK7/gOC6f9Ac8o03HXmaqCQV\nJppwUgpz8dIbowEK7I7YD6wnjedVy5jp+DIJptWfB9n4v/zO2E8a2EOXozLCAElR\nc38K3YUOTL9JSpR7IIG1phhkL2swPXzUefqVtT8SokVPQliGvZ8WQe7mjDDMisjo\nhJu64sUvr4FeNDjkLBixfAyh+ZuJcSH5neuB0QIDAQABAoIBAD0poVwh+MrguCWh\nmBaZzFLRJI4byisdZfVMVaoR5I13UJwj7Q/XW0hG0M8ycMRBGuRZU5IBYc8e4sJh\nwVAwKEpXRYpTRaYc3TUONgrpoQzUhJx9YAS8Gx/a8AIsfe4rfGBcFdGVzl0yF5U+\nkKILDlWc6BZpst7TCvJyUaLpzuXZV9LcsFmhzcNn7Zmyx/c9vkbhLrtq9ocDWQxk\ncV2cYRKF5wj28WZJDe12HuC7S09T/sV9UohL1yRyMIE5+SGBNzW4v6mVvP12yIfP\nTQRbPrmu3Bqm2jt4jK2cRctYybvy2i6Tv+DZRdbph/vc6bxxD/CwT9xuhbY8Sadr\n26FNtAECgYEA/MYNAtm2uM653HM51cUi7AF2IPTAaPZGxvYrEHTGqsMy8ETvdfsp\nm8is3WnznliFXNB95woMLxP7uX9SiTqmwknxHEJMqWE/h2oV/i5+5AQr9aBGWyAJ\n+pYEYBzXLxVLKWdkb9VjW5T/mQly06KHX1zpBp+3o+zM0mktGzwqPsECgYEA8nbS\nuNlfFej3noyEpU5r7WZfYEt4oIxA22jsh+EeybytUOIL+ZlZQjiIn8NSb1Iebrhg\n492xT7Yg3vTN8XEHqH5+x84Z0nSydLlJ/NDG8znCEH4msa3JCH2E+m+LwEKclGw4\nOwaxG050RypU+RhLTKsZF00TC2bhdlAl30v6FxECgYAcYCtDv6b4dhR9P94lNj0m\nWz+kkXUsE0F8wlOxRDqtHr6QJFzxVKGmIE/vhx5XDz7hXXJUxlb5zfd7KmTcjN39\nf4l2j6bFeOpFzE3tu9B4zlMU/soHHsCgBck19ObfHTfTzQyEVWMS+9X5mwrt4Rfr\nR6XNHY7i8wlHMZFjtkxTwQKBgBuCt+4ZW9yUjmQC9Zn8B+rrzq6SYaF1yHYctZnF\nRUUGj3O58jnj2GjXGUlnVBclbiaJ7RRttwygUaJ6jFN0y7WmhKQPEob6jrUHwQla\ndvhp+Ub9yU4ntcOs2kXAGk86P6HnlYm8/KNoh3D7sKCCzShp0XL/X8XPao2OEn3/\nlOTBAoGBAO0owZMm9pdS4s5ap3C9la1LYDKrUxg6tiO9TVsOL1hJmTkA4MWibUMh\nS+cIBUgqFeEApEe5S9MHq4nDwDXjR9vfiIz29uqGZ1vFKO80XSZdBf1WYqFckm9b\ntbdlGrgxwxjPciMl9kcakEas5VVW0cLjQQIU2+55sHEY+xh99bN0\n-----END RSA PRIVATE KEY-----\n",
          "name_parser" => "username"
        }
      else
        {
          "idp_sso_target_url" => "https://saml.chronus.com",
          "idp_cert_fingerprint" => "96:8A:6B:8B:73:57:11:F3:A6:18:52:D6:C6:E2:6C:34:1F:9D:36:68",
          "xmlsec_certificate" => "-----BEGIN CERTIFICATE-----\nMIIDWzCCAkOgAwIBAgIJANezMu+9Ie8PMA0GCSqGSIb3DQEBBQUAMCcxJTAjBgNV\nBAMTHGxlZWRzc2FuZGJveC5yZWFsaXplZ29hbC5jb20wHhcNMTIwNTI4MTEzMjE5\nWhcNMjIwNTI2MTEzMjE5WjAnMSUwIwYDVQQDExxsZWVkc3NhbmRib3gucmVhbGl6\nZWdvYWwuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl+DKdD2k\n9QlSmMT7J4GTRFEo6TCJ7sOnh7sn6s9QpZXsUNgEfhpNzgZrtl2wnAiTxATE6zwt\nUv7cRMKDs7yj9yXs2OmYq8lUlq2gsb72eJ2cgrf3qFnXZzyuVtsPzrlPFZJiEU3w\n0UQsYcLf1SnpN3OpZWVa+JWJCw79tH/ZfY38s69Ho94umTsEou8pjkXaUVxNu1b/\nXX82IB58Vw2wDYyHKIxt4M0lSm8mcf7H/oyTwQzUDvaGDF6zjkerDoYHR/mTippc\nuyxxe/5+PMJ+SnIhLfik+pmMvRsZDGlaFiB0ntMSpI9fqyEhdb9OSU8WvUAcXuMt\nAQD8sq4nqwFF/wIDAQABo4GJMIGGMB0GA1UdDgQWBBSQ1xMNvp9qhTq4DYzCcn/B\nfqC/GTBXBgNVHSMEUDBOgBSQ1xMNvp9qhTq4DYzCcn/BfqC/GaErpCkwJzElMCMG\nA1UEAxMcbGVlZHNzYW5kYm94LnJlYWxpemVnb2FsLmNvbYIJANezMu+9Ie8PMAwG\nA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBAHBnMZVLcKsW3TekE5Haywjb\n+6DIliEEW7Ll2Dm6Obp0eUWCQEMFUM38u11cUNB0USIg2Msf3chiw0hdqjXWBFlC\nfthBLbenj4+gL8V95/5W9XAa+jd1YpW/Fdl8vqqnNMxjMc39SthB0cFpqN7Hi+aB\nglnE+/TIF5PgtjC9v8eWALaqz7cY+9r+m0Br3GWtucl3lg0VTx850I8oKsucBlHK\nrO/GyQlIv51phz8eYTFBn+LwbXZDHpE/4DFGoutaV4Fw1pVbBJZJzQmQeDXQ5dG+\n1UjZ191NN0G5uOdHVkWzKkWrojCeWgKWGTn3ctUwK6W531Wfj6M3gDGfRNk+6Vo=\n-----END CERTIFICATE-----\n",
          "xmlsec_privatekey" => "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAl+DKdD2k9QlSmMT7J4GTRFEo6TCJ7sOnh7sn6s9QpZXsUNgE\nfhpNzgZrtl2wnAiTxATE6zwtUv7cRMKDs7yj9yXs2OmYq8lUlq2gsb72eJ2cgrf3\nqFnXZzyuVtsPzrlPFZJiEU3w0UQsYcLf1SnpN3OpZWVa+JWJCw79tH/ZfY38s69H\no94umTsEou8pjkXaUVxNu1b/XX82IB58Vw2wDYyHKIxt4M0lSm8mcf7H/oyTwQzU\nDvaGDF6zjkerDoYHR/mTippcuyxxe/5+PMJ+SnIhLfik+pmMvRsZDGlaFiB0ntMS\npI9fqyEhdb9OSU8WvUAcXuMtAQD8sq4nqwFF/wIDAQABAoIBAQCVQJ80ZG/7LdIx\nt0JprHigpnFh2AV00mmMhWvQ4TMLxq2ZNPAVTJwxXzXy3Vd1vygXdehek6Cm8zZb\njBwJQdSQSIDdGZKjHxM1kCNfCZ8FIT5xZ4DFvKRmG8foKxb5vDnvpQ8imkmSHUDQ\nQcXdoXZCvDM4Jcaki69FYtIH06xUKPUh/rESJ1e8OF6R1KbvM6TwLyP7v1iVmY2m\nFCTfJXPUXAhafW4gU0VEury0AK40fol+m4vThz9SzVW4kgyqX0PKFV80v+CW1aMt\noUoLXxPrdG5nEcrtDMvIfzrsauIYcNpeGY7Ci2p9/llLi3C+9ALXg3VdMStAdTRM\nuxMOn90hAoGBAMZnvgKOAsV3EQVICA4XF3H8lztp9XZjg3Gmz5NojCm+Hz4LyhF2\nnz9vGjbTyR2ioVG5M51CutgiAruhpsKbL/hWsLxHzp4r1BwpoftWMRv3sbQ3wzWb\np7f6E+kZGTuJ5XpgrlNLf+8amS7V1qh0VHbsUUX53KPfDzyzJVcxGwXVAoGBAMP3\nb8VkXilo0lTrDUuQAZoQ3LaxVoPqqeMpX6gIPPxDL0pDUxva8yiGICjQYiTUSsp6\nDSoU7g/ZXCQqWhH6jANcusnVTHp3iNG1HLUX2jD6A7CJhJ+JFGzmeOdeuUT+6yqE\nqKGpsdGL9uoD8kQSTQZi9kJVrBzZgPiLpP1GSyKDAoGAJHGN315CeA8E21l90UjA\nj7l79ffilJp23HttiYAcrtYzWuxDc628VqSLxiJkwMLMqvw/1NUbCPRGWDy7Kufi\nidUypYLzGu6mCX5EOKx+XMrEo3vSqZgr2Ilg+uIXVm5f7nivzLEDkOHr3UR+J3cm\nxKlnzFi3BIrGe7nUVA27DvkCgYEAoSVkICn81IiCDZqMgEqXRp3/IayKvEfIFCj9\npCvCGp8U0Di0qv9NXVGOOIHDcw2vwvjCwowbh6TyBDtffdFOOaWTZE2maj7Jn8kT\nJkfLAONXDWDIUnhi93o+ieR27anCsGAOW4Iz22EBVkaQfjGebVYLs1jIA6FIURpk\nPnIDbwkCgYBlWTEMLqdSuFVh36FFDMnOwPQ7wqINVfRalSPPbke0exA+q0vgVtug\n5c49X4MowNhyONI6EUzXgMN26+JrWPWE/Z8XwYQXeuvkHDIZpQYwRnwANawbZIO0\nBgfskwgEnHqJIduuJf17uFsUDd7iLyANfZAf+/75RX4WUPfNc093bQ==\n-----END RSA PRIVATE KEY-----\n",
          "friendly_name" => "eduPersonPrincipalName"
        }
      end

    auth_config = organization.auth_configs.new(auth_type: AuthConfig::Type::SAML)
    auth_config.set_options!(options.merge!(config_options))
    auth_config
  end

  def setup_new_user_followup
    @user = users(:f_mentor)
    @member = @user.member
    @program = @user.program
    @organization = @program.organization
    @password = Password.create!(member: @member)

    @member.crypted_password = nil
    @member.save!
    @member.login_identifiers.destroy_all
  end

  def get_pending_requests_and_offers_count(user)
    user.pending_received_mentor_requests.count + user.pending_received_meeting_requests.count + user.pending_received_mentor_offers.count
  end

  def stub_request_parameters(params = {})
    self.stubs(:params).returns(ActionController::Parameters.new(params))
  end

  def import_mentoring_model(mentoring_model, options = {})
    file_path = options[:file_path].presence || File.join("files", "mentoring_model/mentoring_model_import.csv")

    MentoringModel.any_instance.stubs(:increment_version_and_trigger_sync) if options[:skip_increment_version_and_trigger_sync]
    MentoringModel::Importer.new(mentoring_model, fixture_file_upload(file_path, "text/csv")).import
  end

  private

  def get_calendar_event_attendees
    attendees = [
      {
        email: "robert@example.com",
        response_status: "accepted"
      },
      {
        email: "mkr@example.com",
        response_status: "declined"
      }
    ]

    attendees = attendees.map{|attendee| OpenStruct.new attendee}
    return attendees
  end

  # guess the user from the arg
  def guess_user(arg)
    arg.is_a?(Symbol) ? users(arg) : arg
  end

  def guess_member(arg)
    arg.is_a?(Symbol) ? members(arg) : arg
  end

  def redefine_const(name, value, namespace)
    # Store the constant name & its value before redefining it. In this way we can restore the constant back to its original value.
    (@@redefined_constants ||= {})[name] = {:name => name, :old_value => namespace.const_get(name)}
    Object.redefine_constant(name, value, namespace)
  end

  # Used to restore the redefined constant -<name> with its original value.
  def reset_const(name, namespace)
    unless @@redefined_constants[name].nil?
      Object.redefine_constant(name, @@redefined_constants[name][:old_value], namespace)
      @@redefined_constants.delete(name)
    end
  end

  def find_model_with_es_index(klass)
    return klass if klass.__elasticsearch__.index_name == ElasticsearchReindexing.get_index_alias_from_model(klass.name) || klass == klass.base_class
    find_model_with_es_index(klass.base_class)
  end
end

class ActionView::TestCase < ActiveSupport::TestCase
  # FIXME <code>helper :all</code> does not seem to work. Including helpers manually.
  include ApplicationHelper, UsersHelper
end

module ActiveRecord
  class Base
    # Skip automatic AR timestamping - http://bit.ly/bzQJu
    def self.skip_timestamping
      raise "No block given" unless block_given?
      old_setting = self.record_timestamps
      self.record_timestamps = false
      ActiveRecord::Base.no_touching do
        yield
      end
      self.record_timestamps = old_setting
    end
  end
end

# While testing, we may sometimes need to redefined the constants.
# Module is a class provided by ruby which is nothing but a collection of methods & CONSTANTS.
# It also provides some useful functions to deal with CONSTANTS.
# See:
#   http://www.ruby-doc.org/core/classes/Module.html
#         or
#   http://www.ruby-doc.org/docs/ProgrammingRuby/html/ref_c_module.html
# Here we are inserting the function "redefine_constant" into the Module class for our convenience.
class Module
  def redefine_constant(name, value, namespace)
    namespace.__send__(:remove_const, name) if namespace.const_defined?(name)
    namespace.const_set(name, value)
  end
end

module Hpricot
  # Monkeypatch to fix an Hpricot bug that causes HTML entities to be decoded
  # incorrectly.
  def self.uxs(str)
    str.to_s.
      gsub(/&(\w+);/) { [Hpricot::NamedCharacters[$1] || ??].pack("U*") }.
      gsub(/\&\#(\d+);/) { [$1.to_i].pack("U*") }
  end
end

class ActiveSupport::TestCase
  teardown :reconsider_gc_deferment

  unless ActiveSupport::TestCase.const_defined?("DEFERRED_GC_THRESHOLD")
    DEFERRED_GC_THRESHOLD = (ENV['DEFER_GC'] || 10.0).to_f
  end

  @@last_gc_run = Time.now
  @@reserved_ivars = %w(@loaded_fixtures @test_passed @method_name @_assertion_wrapped @_result)

  def reconsider_gc_deferment
    if ENV['TDDIUM'] == false
      if DEFERRED_GC_THRESHOLD > 0 && Time.now - @@last_gc_run >= DEFERRED_GC_THRESHOLD
        GC.enable
        GC.start
        GC.disable
        @@last_gc_run = Time.now
      end
    end
  end

  def scrub_instance_variables
    (instance_variables - @@reserved_ivars).each do |ivar|
      instance_variable_set(ivar, nil)
    end
  end
end

# Workaround for the below issue to avoid the following error when running integration tests with something like Capybara and Selenium or Capybara and Webkit:
# Mysql2::Error: This connection is still waiting for a result, try again once you have the result
# Adapted from the below links
# https://gist.github.com/mperham/3049152
# https://github.com/brianmario/mysql2/issues/99#issuecomment-2447131
# https://github.com/zdennis/activerecord-mysql2-retry-ext
if ENV['CUCUMBER_ENV'] || ENV['TDDIUM']
  require 'connection_pool'

  class ActiveRecord::Base
    mattr_accessor :shared_connection
    @@shared_connection = nil

    def self.connection
      @@shared_connection || ConnectionPool::Wrapper.new(:size => 1) { retrieve_connection }
    end
  end
  ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection
end

SP_BASE_PATH_FOR_EXPORT_TEST = SolutionPack::PARENT_DIRECTORY_PATH+"/SolutionPack_1234_5678/"
SP_BASE_PATH_FOR_IMPORT_TEST = Rails.root.to_s+SolutionPack::PARENT_DIRECTORY_PATH+"/solution_pack_for_import#{ENV["TEST_ENV_NUMBER"]}"

def copy_base_dir_for_import
  FileUtils.mkdir_p(SP_BASE_PATH_FOR_IMPORT_TEST) unless Dir.exist?(SP_BASE_PATH_FOR_IMPORT_TEST)
  FileUtils.copy_entry "test/fixtures/files/solution_pack_import", SP_BASE_PATH_FOR_IMPORT_TEST
end

def delete_base_dir_for_import
  FileUtils.rm_rf(SP_BASE_PATH_FOR_IMPORT_TEST) if Dir.exist?(SP_BASE_PATH_FOR_IMPORT_TEST)
end

def set_ck_editor_attributes_for_solution_pack(solution_pack)
  ck_editor_rows_with_column_names = CSV.read(solution_pack.base_directory_path+CkeditorAssetExporter::FileName+".csv")
  solution_pack.ck_editor_column_names = ck_editor_rows_with_column_names[0]
  solution_pack.ck_editor_rows = ck_editor_rows_with_column_names[1..-1]
end

# used to validate the data populated for a model, has to use in all populator tests
def populator_object_save!(obj)
  obj.save!
end

def load_populator_manager_test(populator_spec_file, test_spec_file)
  perf_populator = PopulatorManager.new(:spec_file_path => populator_spec_file)
  test_spec_hash = YAML.load_file(test_spec_file)
  perf_populator.nodes.deep_merge!(test_spec_hash)
  perf_populator
end

def populator_add_and_remove_objects(object, parent_class, to_add_parent_ids, to_remove_parent_ids, options={})
  populator_add_or_remove_objects(object, parent_class, to_add_parent_ids, :add, options)
  populator_add_or_remove_objects(object, parent_class, to_remove_parent_ids, :remove, options)
end

def setup_banner_fallback(organization, program)
  if program
    ProgramAsset.find_or_create_by(program_id: program.id)
    program.program_asset.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    program.program_asset.save!
  end
  ProgramAsset.find_or_create_by(program_id: organization.id)
  organization.program_asset.banner = fixture_file_upload(File.join('files', 'pic_2.png'), 'image/png')
  organization.program_asset.save!
end

def populator_add_or_remove_objects(object, parent_class, parent_ids, action, options={})
  populator_class = (object.camelize + "Populator").constantize
  additional_populator_class_options = options[:additional_populator_class_options] || {}
  populator_class_options = {parent: parent_class, percents_ary: [50, 25, 25], counts_ary: [3, 2, 1], common: {"translation_locales" => ["en"]}}
  populator_class_options.merge!(additional_populator_class_options)
  populator_object = populator_class.new(object, populator_class_options)
  method = "#{action.to_s}_#{object.pluralize}"
  count = additional_populator_class_options[:obj_count] || 1
  obj_count = parent_ids.size * count
  obj_count = -obj_count if action.equal?(:remove)
  model = (options[:model] || object).camelize.constantize
  translation_locales = additional_populator_class_options.try(:[], :common).try(:[], "translation_locales")
  translation_model = (options[:translation_model] || model)::Translation if translation_locales.present?
  old_translation_count = translation_model.count if translation_model && action.equal?(:add)

  assert_difference "model.count", obj_count do
    populator_object.send(method.to_sym, parent_ids, count, options.except(:additional_populator_class_options, :translation_model))
  end
  if translation_model && action.equal?(:add)
    assert_equal translation_model.count, old_translation_count + translation_locales.count*obj_count
    assert translation_locales.count*obj_count > 0
    locale_translation_count = translation_model.last(translation_locales.count*obj_count).group_by(&:locale).collect{|k,v| v.count}
    assert_equal translation_locales.count, locale_translation_count.size
    assert_equal translation_locales.count, locale_translation_count.size
    translation_locales.each do |locale|
      attribute = (options[:translation_model] || model).translated_attribute_names.first
      assert /- #{locale}$/ === translation_model.order("id desc").find_by(locale: locale).send(attribute)
    end
    assert_equal [obj_count], locale_translation_count.uniq
  end
  if action.equal?(:add) && (!additional_populator_class_options[:ignore_save_check])
    last_obj = model.last
    populator_object_save!(last_obj)
    options[:attribute_asserts].each do |assert_info|
      assert_equal assert_info[:expect], last_obj.send(assert_info[:attribute]) if assert_info[:method] == :assert_equal
    end if options[:attribute_asserts]
  end
end