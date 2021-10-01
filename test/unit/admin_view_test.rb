require_relative './../test_helper.rb'

class AdminViewTest < ActiveSupport::TestCase
  TEMP_CSV_FILE = "tmp/test_file.csv"
  def test_validations
    admin_view = AdminView.new
    assert_false admin_view.valid?
    assert_equal(["can't be blank"], admin_view.errors[:title])
    assert_equal(["can't be blank"], admin_view.errors[:program])
    assert_equal(["can't be blank"], admin_view.errors[:filter_params])

    admin_view = AdminView.create!(:title => "Sample View", :program => programs(:albers), :filter_params => {}.to_yaml)
    assert admin_view.valid?
  end

  def test_get_first_admin_view_name_should_return_proper_value
    campaign = cm_campaigns(:active_campaign_1)
    admin_view = AdminView.find_by(title: "All Users")
    assert_equal admin_view, AdminView.get_first_admin_view(campaign, programs(:albers).id)
    program = programs(:albers)
    resource = create_resource(title: "Cercei Lannister", content: "Jaime Lannister")
    resource_publication = program.resource_publications.create!(resource: resource)
    resource_publication.update_attributes(admin_view_id: admin_view.id)
    resource_publication.reload
    assert_equal admin_view, AdminView.get_first_admin_view(resource, programs(:albers).id)
  end

  def test_resource_publication_association
    program = programs(:albers)
    admin_view = program.admin_views.first
    resource = create_resource(title: "Cercei Lannister", content: "Jaime Lannister")
    resource_publication = program.resource_publications.create!(resource: resource)
    resource_publication.update_attributes(admin_view_id: admin_view.id)
    resource_publication.reload
    assert_equal resource_publication, admin_view.resource_publications.first
  end

  def test_validation_title_uniqueness
    program = programs(:albers)

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :title do
      program.admin_views.create!(:title => "All Users", :filter_params => AdminView.convert_to_yaml({:sample => "hello"}))
    end

    assert_nothing_raised do
      program.admin_views.create!(:title => "Sample view", :filter_params => AdminView.convert_to_yaml({:sample => "hello"}))
    end

    assert_nothing_raised do
      programs(:psg).admin_views.create!(:title => "Sample view", :filter_params => AdminView.convert_to_yaml({:sample => "hello"}))
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :title do
      programs(:psg).admin_views.create!(:title => "Sample view", :filter_params => AdminView.convert_to_yaml({:sample => "hello"}))
    end
  end

  def test_admin_view_user_caches_association
    all_members_view = programs(:org_primary).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS)
    all_users_view = programs(:albers).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    assert_nil all_members_view.admin_view_user_cache
    admin_view_user_cache = AdminViewUserCache.find_by(admin_view_id: all_users_view.id)
    assert_equal admin_view_user_cache, all_users_view.admin_view_user_cache
    assert_difference "AdminViewUserCache.count", -1 do
      all_users_view.destroy
    end
  end

  def test_can_create_admin_view_user_cache
    all_members_view = programs(:org_primary).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS)
    all_users_view = programs(:albers).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    assert_false all_members_view.can_create_admin_view_user_cache?
    assert_false all_users_view.can_create_admin_view_user_cache?
    all_users_view.admin_view_user_cache.destroy
    assert all_users_view.reload.can_create_admin_view_user_cache?
  end

  def test_editable
    filter_params = {:roles_and_status => {role_filter_1: {type: :include, :roles => ["#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME},#{RoleConstants::STUDENT_NAME}"].split(',')}},
      :connection_status => {:status => "", :availability => {:operator => "", :value => ""}},
      :profile => {:questions => {:questions_1 => {:question => "", :operator => "", :value => ""}}, :score => {:operator => "", :value => ""}},
      :others => {:tags => ""}
    }
    admin_view = programs(:albers).admin_views.create!(:title => "Sample Test View", :filter_params => AdminView.convert_to_yaml(filter_params), :default_view => AdminView::EDITABLE_DEFAULT_VIEWS.first)
    assert admin_view.editable?

    admin_view = programs(:albers).admin_views.create!(:title => "Sample Test View 1", :filter_params => AdminView.convert_to_yaml(filter_params), :default_view => AbstractView::DefaultType::ALL_USERS)
    assert_false admin_view.editable?

    admin_view = programs(:albers).admin_views.create!(:title => "Sample Test View 2", :filter_params => AdminView.convert_to_yaml(filter_params))
    assert admin_view.editable?
  end

  def test_default_view_for_match_report
    admin_view = AbstractView.find_by(default_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTEES)
    assert admin_view.default_view_for_match_report?
    
    admin_view = AbstractView.find_by(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES)
    assert admin_view.default_view_for_match_report?

    admin_view = AbstractView.find_by(default_view: AbstractView::DefaultType::ACCEPTED_BUT_NOT_JOINED)
    assert_false admin_view.default_view_for_match_report?
  end

  def test_deletable
    admin_view = AbstractView.find_by(default_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTEES)
    
    admin_view.stubs(:editable?).returns(true)
    admin_view.stubs(:default_view_for_match_report?).returns(true)
    assert_false admin_view.deletable?

    admin_view.stubs(:editable?).returns(false)
    assert_false admin_view.deletable?

    admin_view.stubs(:default_view_for_match_report?).returns(false)
    assert_false admin_view.deletable?

    admin_view.stubs(:editable?).returns(true)
    assert admin_view.deletable?
  end

  def test_process_role_status_params
    admin_view = programs(:albers).admin_views.first
    with, options, with_all, should_not_options, should_options = [{}, {}, {} , [], []]
    parameters = {
      role_filter_1: {type: :include, roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]},
      role_filter_2: {type: :include, roles: [RoleConstants::ADMIN_NAME]},
      role_filter_3: {type: :exclude, roles: [RoleConstants::MENTOR_NAME, RoleConstants::ADMIN_NAME]},
      role_filter_4: {type: :exclude, roles: [RoleConstants::STUDENT_NAME, RoleConstants::ADMIN_NAME]},
      :state => {:active => "active"}
    }
    mentor_id = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    admin_id = programs(:albers).get_role(RoleConstants::ADMIN_NAME).id
    student_id = programs(:albers).get_role(RoleConstants::STUDENT_NAME).id
    admin_view.process_role_status_params!(parameters, with, with_all, should_not_options, should_options)
    assert_equal({state: ["active"]}, with)
    assert_equal({"roles.id" => [[mentor_id, student_id], [admin_id]]}, with_all)
    assert_equal "mentor,student,admin", admin_view.get_included_roles_string(parameters)
    assert_equal [ { filters: [ { with_all_filters: { "roles.id" => [admin_id, admin_id] } }, { with_all_filters: { "roles.id" => [admin_id, student_id] } }, { with_all_filters: { "roles.id" => [mentor_id, admin_id] } }, { with_all_filters: { "roles.id"=>[mentor_id, student_id] } } ] } ], should_not_options
    assert_equal [], should_options

    with, options, with_all, should_not_options, should_options = [{}, {}, {} , [], []]
    parameters = {role_filter_1: {type: :include, roles: [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]}, :state => {:active => "active"}}
    admin_view.process_role_status_params!(parameters, with, with_all, should_not_options, should_options)
    role_ids = programs(:albers).get_roles([RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).collect(&:id)
    assert_equal({"roles.id" => [role_ids]}, with_all)
    assert_equal({state: ["active"]}, with)
    assert_equal "admin,mentor,student", admin_view.get_included_roles_string(parameters)
    assert_equal [], should_not_options
    assert_equal [], should_options

    with, options, with_all, should_not_options, should_options = [{}, {}, {} , [], []]
    parameters = {role_filter_1: {type: :include, roles: [RoleConstants::MENTOR_NAME]}}
    admin_view.process_role_status_params!(parameters, with, with_all, should_not_options, should_options)
    assert_equal({}, with)
    assert_equal({"roles.id" => [[mentor_id]]}, with_all)
    assert_equal RoleConstants::MENTOR_NAME, admin_view.get_included_roles_string(parameters)
    assert_equal [], should_not_options
    assert_equal [], should_options

    role_ids = programs(:albers).get_roles(RoleConstants::MENTOR_NAME).collect(&:id)
    test_set = [
      [{added_not_signed_up_users: 'added_not_signed_up_users'}, [{filters: [{must_not_filters: {exists_query: :last_seen_at, creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}}]}]],
      [{accepted_not_signed_up_users: 'accepted_not_signed_up_users'}, [{filters: [{must_not_filters: {exists_query: :last_seen_at}, must_filters: {creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}}]}]],
      [{signed_up_users: 'signed_up_users'}, [{filters: [{must_filters: {exists_query: :last_seen_at}}]}]],
      [{added_not_signed_up_users: 'added_not_signed_up_users', accepted_not_signed_up_users: 'accepted_not_signed_up_users'}, [{filters: [{must_not_filters: {exists_query: :last_seen_at, creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}}, {must_not_filters: {exists_query: :last_seen_at}, must_filters: {creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}}]}]],
      [{added_not_signed_up_users: 'added_not_signed_up_users', signed_up_users: 'signed_up_users'}, [{filters: [{must_not_filters: {exists_query: :last_seen_at, creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}}, {must_filters: {exists_query: :last_seen_at}}]}]],
      [{accepted_not_signed_up_users: 'accepted_not_signed_up_users', signed_up_users: 'signed_up_users'}, [{filters: [{must_not_filters: {exists_query: :last_seen_at}, must_filters: {creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}}, {must_filters: {exists_query: :last_seen_at}}]}]],
      [{added_not_signed_up_users: 'added_not_signed_up_users', accepted_not_signed_up_users: 'accepted_not_signed_up_users', signed_up_users: 'signed_up_users'}, [{filters: [{must_not_filters: {exists_query: :last_seen_at, creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}}, {must_not_filters: {exists_query: :last_seen_at}, must_filters: {creation_source: User::CreationSource::MEMBERSHIP_REQUEST_ACCEPTED}}, {must_filters: {exists_query: :last_seen_at}}]}]]
    ]
    test_set.each do |val|
      with, options, with_all, should_not_options, should_options = [{}, {}, {} , [], []]
      parameters = {role_filter_1: {type: :include, roles: [RoleConstants::MENTOR_NAME]}, role_filter_2: {type: :exclude, roles: [RoleConstants::STUDENT_NAME]}, signup_state: val[0]}
      admin_view.process_role_status_params!(parameters, with, with_all, should_not_options, should_options)
      assert_equal(val[1], should_options)
      assert_equal [ { filters: [ { with_all_filters: { "roles.id" => [student_id] } } ] } ], should_not_options
      assert_equal({}, with)
      assert_equal( { "roles.id" => [[mentor_id]] }, with_all)
    end
  end

  def test_profile_question_text_method
    assert_equal [:question_text_with_mandatory_mark, programs(:albers).roles], programs(:albers).admin_views.first.profile_question_text_method
    assert_equal [:question_text], programs(:org_primary).admin_views.first.profile_question_text_method
  end

  def test_get_mandatory_filter_data
    admin_view = programs(:albers).admin_views.first
    hash_options, profile_param = [{}, {}]
    admin_view.send(:get_mandatory_filter_data, profile_param, hash_options)
    assert_equal_hash({}, hash_options)
    hash_options, profile_param = [{}, {mandatory_filter: AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_MANDATORY_QUESTIONS}]
    admin_view.send(:get_mandatory_filter_data, profile_param, hash_options)
    assert_equal_hash({"Users who have"=>"Not answered all mandatory questions"}, hash_options)
    hash_options, profile_param = [{}, {mandatory_filter: AdminView::MandatoryFilterOptions::FILLED_ALL_MANDATORY_QUESTIONS}]
    admin_view.send(:get_mandatory_filter_data, profile_param, hash_options)
    assert_equal_hash({"Users who have"=>"Answered all mandatory questions"}, hash_options)
    hash_options, profile_param = [{}, {mandatory_filter: AdminView::MandatoryFilterOptions::FILLED_ALL_QUESTIONS}]
    admin_view.send(:get_mandatory_filter_data, profile_param, hash_options)
    assert_equal_hash({"Users who have"=>"Answered all questions"}, hash_options)
    hash_options, profile_param = [{}, {mandatory_filter: AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_QUESTIONS}]
    admin_view.send(:get_mandatory_filter_data, profile_param, hash_options)
    assert_equal_hash({"Users who have"=>"Not answered all questions"}, hash_options)
  end

  def test_process_other_params
    admin_view = programs(:albers).admin_views.first
    user = users(:f_mentor)

    with = {}
    admin_view.process_other_params!({}, with)
    assert_equal({}, with)

    admin_view.process_other_params!({:tags => "1,2,3"}, with)
    assert_equal({"taggings.tag_id" => [0]}, with)

    admin_view.process_other_params!({:tags => "tag1,tag3"}, with)
    assert_equal({"taggings.tag_id" => [1, 3]}, with)
  end

  def test_process_params_for_tags
    admin_view = admin_views(:admin_views_25)
    admin_view.update_attributes!(filter_params: AdminView.convert_to_yaml({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>["mentor", "student"]}}, "others" => {"tags" => "tag3"}}))
    assert_equal [users(:f_mentor_student).id], admin_view.generate_view("", "", false)

    admin_view.update_attributes!(filter_params: AdminView.convert_to_yaml({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>["mentor", "student"]}}, "others" => {"tags" => "invalid_tag"}}))
    assert_equal_unordered [], admin_view.generate_view("", "", false)
  end

  def test_remove_tags
    user = users(:f_mentor)
    user.tag_list = "a,b,c"
    user.save!

    AdminView.remove_tags([user.id], "a,b,d")
    assert_equal ["c"], user.reload.tag_list
  end

  def test_refresh_user_ids_cache
    admin_view = programs(:albers).admin_views.first
    admin_view.expects(:generate_view).with("", "", false).once.returns([1,2,3])
    assert_no_difference "AdminViewUserCache.count" do
      admin_view.refresh_user_ids_cache
    end
    admin_view_user_cache = admin_view.reload.admin_view_user_cache
    assert_equal "1,2,3", admin_view_user_cache.user_ids
    admin_view.admin_view_user_cache.destroy

    admin_view.expects(:generate_view).with("", "", false).once.returns([1,2,3,4])
    assert_difference "AdminViewUserCache.count", 1 do
      admin_view.refresh_user_ids_cache
    end
    admin_view_user_cache = admin_view.reload.admin_view_user_cache
    assert_equal "1,2,3,4", admin_view_user_cache.user_ids
  end

  def test_create_or_update_user_ids_cache
    admin_view = programs(:albers).admin_views.first
    time = DateTime.now
    DateTime.stubs(:now).returns(time)
    assert_no_difference "AdminViewUserCache.count" do
      admin_view.create_or_update_user_ids_cache([1, 2, 3])
    end
    admin_view_user_cache = admin_view.reload.admin_view_user_cache
    assert_equal "1,2,3", admin_view_user_cache.user_ids
    assert_equal time.utc.to_s, admin_view_user_cache.last_cached_at.to_datetime.utc.to_s
    admin_view.admin_view_user_cache.destroy
    time = DateTime.now
    DateTime.stubs(:now).returns(time)
    assert_difference "AdminViewUserCache.count", 1 do
      admin_view.create_or_update_user_ids_cache([1, 2, 3])
    end
    admin_view_user_cache = admin_view.reload.admin_view_user_cache
    assert_equal "1,2,3", admin_view_user_cache.user_ids
    assert_equal time.utc.to_s, admin_view_user_cache.last_cached_at.to_datetime.utc.to_s

    assert_no_difference "AdminViewUserCache.count" do
      admin_view.create_or_update_user_ids_cache([1,2])
    end
    admin_view_user_cache = admin_view.reload.admin_view_user_cache
    assert_equal "1,2", admin_view_user_cache.user_ids
  end

  def test_get_connection_status_filters
    admin_view = programs(:albers).admin_views.first

    admin_view.send(:get_connection_status_filters, {
      status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS, AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::LESS_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 100},
      status_filter_1: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::GREATER_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 10},
      status_filter_2: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => "", AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 5},
      status_filter_5: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 25},
      status_filter_6: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 15},
      status_filter_7: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::DRAFTED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::LESS_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 10}
    }, (hash_options = {}))
    assert_equal({"User's mentoring connection status"=>"Number of ongoing mentoring connections less than 100, number of ongoing mentoring connections greater than 10, number of past mentoring connections equals to 25, number of ongoing or past mentoring connections equals to 15 and number of drafted mentoring connections less than 10"}, hash_options)

    admin_view.send(:get_connection_status_filters, {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED}}, (hash_options = {}))
    assert_equal({"User's mentoring connection status"=>"Never connected"}, hash_options)

    admin_view.send(:get_connection_status_filters, {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::CURRENTLY_CONNECTED}}, (hash_options = {}))
    assert_equal({"User's mentoring connection status"=>"Currently connected"}, hash_options)

    admin_view.send(:get_connection_status_filters, {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED}}, (hash_options = {}))
    assert_equal({"User's mentoring connection status"=>"Currently not connected"}, hash_options)

    admin_view.send(:get_connection_status_filters, {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED}}, (hash_options = {}))
    assert_equal({"User's mentoring connection status"=>"Currently connected for first time"}, hash_options)

    admin_view.send(:get_connection_status_filters, {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST}}, (hash_options = {}))
    assert_equal({"User's mentoring connection status"=>"Connected (currently or in the past)"}, hash_options)
  end

  def test_process_connection_status_params
    selected_roles = RoleConstants::DEFAULT_ROLE_NAMES.join(",")
    admin_view = programs(:albers).admin_views.first

    with = {}
    without = {}
    admin_view.process_connection_status_params!({}, selected_roles, with, without)
    assert_equal({}, with)

    programs(:albers).enable_feature(FeatureName::CALENDAR, true)
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    programs(:albers).allow_mentoring_mode_change = Program::MENTORING_MODE_CONFIG::EDITABLE
    programs(:albers).save!

    admin_view.reload

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:mentoring_model_preference => User::MentoringMode::ONE_TIME}, selected_roles, with, without)
    assert_equal({mentoring_mode: [2, 3]}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:mentoring_model_preference => User::MentoringMode::ONE_TIME}, RoleConstants::STUDENT_NAME, with, without)
    assert_equal({}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:mentoring_model_preference => User::MentoringMode::ONGOING}, selected_roles, with, without)
    assert_equal({mentoring_mode: [1, 3]}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:mentoring_model_preference => User::MentoringMode::ONE_TIME_AND_ONGOING}, selected_roles, with, without)
    assert_equal({mentoring_mode: [1, 3, 2]}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:mentoring_model_preference => User::MentoringMode::NOT_APPLICABLE}, selected_roles, with, without)
    assert_equal({}, with)


    admin_view.process_connection_status_params!({:availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}}, selected_roles, with, without)
    assert_equal({:availability=>0..1}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:availability => {:operator => AdminViewsHelper::QuestionType::HAS_GREATER_THAN.to_s, :value => 2}}, selected_roles, with, without)
    assert_equal({:availability=>3..100}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:availability => {:operator => AdminViewsHelper::QuestionType::HAS_GREATER_THAN.to_s, :value => 2}}, RoleConstants::STUDENT_NAME, with, without)
    assert_equal({}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:status => UsersIndexFilters::Values::CONNECTED}, selected_roles, with, without)
    assert_equal({:active_user_connections_count=>1..1000000000}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:status => UsersIndexFilters::Values::UNCONNECTED}, selected_roles, with, without)
    assert_equal({:active_user_connections_count=>0}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}, :status => UsersIndexFilters::Values::UNCONNECTED}, selected_roles, with, without)
    assert_equal({:availability=>0..1, :active_user_connections_count=>0}, with)
    assert_false with.keys.include?(:latest_closed_group_time)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:draft_status => AdminView::DraftConnectionStatus::WITH_DRAFTS}, selected_roles, with, without)
    assert_equal({:draft_connections_count=>1..1000000000}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:draft_status => AdminView::DraftConnectionStatus::WITHOUT_DRAFTS}, selected_roles, with, without)
    assert_equal({:draft_connections_count=>0}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:draft_status => AdminView::DraftConnectionStatus::WITH_DRAFTS}, RoleConstants::MENTOR_NAME, with, without)
    assert_equal({:draft_connections_count=>1..1000000000}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:draft_status => AdminView::DraftConnectionStatus::WITH_DRAFTS}, RoleConstants::ADMIN_NAME, with, without)
    assert_equal({}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:draft_status => AdminView::DraftConnectionStatus::WITHOUT_DRAFTS}, RoleConstants::STUDENT_NAME, with, without)
    assert_equal({:draft_connections_count=>0}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:status => UsersIndexFilters::Values::UNCONNECTED, :draft_status => AdminView::DraftConnectionStatus::WITH_DRAFTS}, RoleConstants::STUDENT_NAME, with, without)
    assert_equal({:active_user_connections_count=>0, :draft_connections_count=>1..1000000000}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:status => UsersIndexFilters::Values::UNCONNECTED, :draft_status => AdminView::DraftConnectionStatus::WITHOUT_DRAFTS}, RoleConstants::MENTOR_NAME, with, without)
    assert_equal({:active_user_connections_count=>0, :draft_connections_count=>0}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:status => UsersIndexFilters::Values::UNCONNECTED, :draft_status => AdminView::DraftConnectionStatus::WITHOUT_DRAFTS}, RoleConstants::ADMIN_NAME, with, without)
    assert_equal({}, with)

    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    admin_view.reload

    program = programs(:albers)

    with = {}
    without = {}
    assert_equal_unordered program.mentor_requests.pluck(:receiver_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "", :mentees => ""}, :mentoring_requests => {:mentors => "1", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}}, selected_roles, with, without)

    assert_equal_unordered program.mentor_requests.pluck(:sender_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "", :mentees => ""}, :mentoring_requests => {:mentors => "", :mentees => "1"}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}}, selected_roles, with, without)

    assert_equal_unordered program.meeting_requests.pluck(:receiver_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "1", :mentees => ""}, :mentoring_requests => {:mentors => "", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}}, selected_roles, with, without)

    assert_equal_unordered program.meeting_requests.pluck(:sender_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "", :mentees => "1"}, :mentoring_requests => {:mentors => "", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}}, RoleConstants::STUDENT_NAME, with, without)

    assert_equal_unordered program.mentor_requests.where(:status => AbstractRequest::Status::NOT_ANSWERED).collect(&:receiver_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "", :mentees => ""}, :mentoring_requests => {:mentors => "2", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}}}, RoleConstants::MENTOR_NAME, with, without)

    assert_equal_unordered program.mentor_requests.where(:status => AbstractRequest::Status::REJECTED).collect(&:receiver_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "", :mentees => ""}, :mentoring_requests => {:mentors => "4", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}}}, RoleConstants::MENTOR_NAME, with, without)

    mentor_requests(:mentor_request_0).update_attributes!(status: AbstractRequest::Status::CLOSED, closed_at: Time.now)
    reindex_documents(updated: mentor_requests(:mentor_request_0))
    assert_equal_unordered program.mentor_requests.where(:status => AbstractRequest::Status::CLOSED).collect(&:receiver_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "", :mentees => ""}, :mentoring_requests => {:mentors => "5", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}}}, RoleConstants::MENTOR_NAME, with, without)

    assert_equal_unordered program.mentor_requests.where(:status => AbstractRequest::Status::NOT_ANSWERED).collect(&:sender_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "", :mentees => ""}, :mentoring_requests => {:mentors => "", :mentees => "2"}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}}}, selected_roles, with, without)

    assert_equal_unordered program.meeting_requests.where(:status => AbstractRequest::Status::NOT_ANSWERED).collect(&:receiver_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "2", :mentees => ""}, :mentoring_requests => {:mentors => "", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}}}, selected_roles, with, without)

    assert_equal_unordered program.meeting_requests.where(:status => AbstractRequest::Status::NOT_ANSWERED).collect(&:sender_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "", :mentees => "2"}, :mentoring_requests => {:mentors => "", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}}}, selected_roles, with, without)

    assert_equal_unordered program.meeting_requests.where(:status => AbstractRequest::Status::REJECTED).collect(&:receiver_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "4", :mentees => ""}, :mentoring_requests => {:mentors => "", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}}}, selected_roles, with, without)

    to_be_closed = program.meeting_requests.last
    to_be_closed.update_attributes!(status: AbstractRequest::Status::CLOSED, closed_at: Time.now)
    reindex_documents(updated: to_be_closed)
    assert_equal_unordered program.meeting_requests.where(:status => AbstractRequest::Status::CLOSED).collect(&:receiver_id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "5", :mentees => ""}, :mentoring_requests => {:mentors => "", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}}}, selected_roles, with, without)

    assert_equal_unordered program.users.pluck(:id), admin_view.process_connection_status_params!({:meetingconnection_status => "", :meeting_requests => {:mentors => "", :mentees => "2"}, :mentoring_requests => {:mentors => "", :mentees => ""}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}, :mentees => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2055", "3" => ""}}}}, RoleConstants::ADMIN_NAME, with, without)

    with = {}
    without = {}
    assert_equal program.users.pluck(:id), admin_view.process_connection_status_params!({:meetingconnection_status => "1", :meeting_requests => {:mentors => "3", :mentees => "3"}, :mentoring_requests => {:mentors => "3", :mentees => "3"}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/1985"}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/1985"}}, :meeting_requests => {:mentors => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/1985"}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/1985"}}, :meetingconnection_status => {:both => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/1985"}}}}, selected_roles, with, without)
    without_ids = program.mentor_requests.pluck(:receiver_id) + program.mentor_requests.pluck(:sender_id) + program.meeting_requests.pluck(:receiver_id) + program.meeting_requests.pluck(:sender_id) + program.meeting_requests.where(:status => AbstractRequest::Status::ACCEPTED).collect(&:receiver_id) + program.meeting_requests.where(:status => AbstractRequest::Status::ACCEPTED).collect(&:sender_id)
    assert_equal_unordered without_ids.uniq, without[:id].to_a

    with = {}
    without = {}
    assert_equal [], admin_view.process_connection_status_params!({:meetingconnection_status => "2", :meeting_requests => {:mentors => "3", :mentees => "3"}, :mentoring_requests => {:mentors => "3", :mentees => "3"}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}}}, selected_roles, with, without)
    without_ids = program.mentor_requests.pluck(:receiver_id) + program.mentor_requests.pluck(:sender_id) + program.meeting_requests.pluck(:receiver_id) + program.meeting_requests.pluck(:sender_id)
    assert_equal_unordered without_ids.uniq, without[:id].to_a

    with = {}
    without = {}
    assert_equal program.users.pluck(:id), admin_view.process_connection_status_params!({:meetingconnection_status => "2", :meeting_requests => {:mentors => "3", :mentees => "3"}, :mentoring_requests => {:mentors => "3", :mentees => "3"}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}}}, RoleConstants::ADMIN_NAME, with, without)
    assert_equal({}, without)


    # test for coach rating sphinx options
    with = {}
    without = {}
    admin_view.process_connection_status_params!({:rating => {:operator => AdminViewsHelper::Rating::EQUAL_TO.to_s, :equal_to => 4}}, selected_roles, with, without)
    assert_equal({}, with)

    programs(:albers).enable_feature(FeatureName::COACH_RATING)
    admin_view.reload

    delta = UserStat::Rating::DELTA
    min = UserStat::Rating::MIN_RATING
    max = UserStat::Rating::MAX_RATING

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:rating => {:operator => AdminViewsHelper::Rating::EQUAL_TO, :equal_to => 4}}, selected_roles, with, without)
    assert_equal({"user_stat.average_rating" => 4.0..4.0}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:rating => {:operator => AdminViewsHelper::Rating::EQUAL_TO, :equal_to => 4}}, RoleConstants::STUDENT_NAME, with, without)
    assert_equal({}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:rating => {:operator => AdminViewsHelper::Rating::LESS_THAN, :less_than => 4}}, selected_roles, with, without)
    assert_equal({"user_stat.average_rating" => min..4-delta}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:rating => {:operator => AdminViewsHelper::Rating::GREATER_THAN, :greater_than => 4}}, selected_roles, with, without)
    assert_equal({"user_stat.average_rating" => 4+delta..max}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:rating => {:operator => AdminViewsHelper::Rating::NOT_RATED}}, selected_roles, with, without)
    assert_equal({exists_query: "user_stat.average_rating"}, without)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({:rating => {}}, selected_roles, with, without)
    assert_equal({}, with)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({}, selected_roles, with, without)
    assert_equal({}, with)
  end


  def test_process_connection_status_params_for_mentor_recommendations
    program = programs(:albers)
    admin_view = program.admin_views.first
    selected_roles = RoleConstants::STUDENT_NAME
    with = {}
    without = {}
    admin_view.stubs(:can_show_mentor_recommendation_filter?).returns(true)
    assert_equal [users(:rahim).id], admin_view.process_connection_status_params!({mentor_recommendations: {mentees: "1"}, advanced_options: {mentor_recommendations: { mentees: {request_duration: "4", "1" => "", "2" => "",  "3" => ""}}}}, selected_roles, with, without)
    assert_equal({}, with)
    assert_equal({}, without)

    with = {}
    without = {}
    admin_view.process_connection_status_params!({mentor_recommendations: {mentees: "2"}, advanced_options: {mentor_recommendations: { mentees: {request_duration: "4", "1" => "", "2" => "",  "3" => ""}}}}, selected_roles, with, without)
    assert_equal({}, with)
    assert_equal [users(:rahim).id], without[:id]

    mentor_recommendations(:mentor_recommendation_1).update_attributes!(status: MentorRecommendation::Status::DRAFTED)
    reindex_documents(updated: mentor_recommendations(:mentor_recommendation_1))
    with = {}
    without = {}

    admin_view.stubs(:can_show_mentor_recommendation_filter?).returns(true)
    assert_equal [], admin_view.process_connection_status_params!({mentor_recommendations: {mentees: "1"}, advanced_options: {mentor_recommendations: { mentees: {request_duration: "4", "1" => "", "2" => "",  "3" => ""}}}}, selected_roles, with, without)
    assert_equal({}, with)
    assert_equal({}, without)


    mentor_recommendations(:mentor_recommendation_1).update_attributes!(status: MentorRecommendation::Status::PUBLISHED, published_at: 3.day.ago)
    reindex_documents(updated: mentor_recommendations(:mentor_recommendation_1))
    with = {}
    without = {}

    admin_view.stubs(:can_show_mentor_recommendation_filter?).returns(true)
    assert_equal [users(:rahim).id], admin_view.process_connection_status_params!({mentor_recommendations: {mentees: "1"}, advanced_options: {mentor_recommendations: { mentees: {request_duration: "1", "1" => "4", "2" => "",  "3" => ""}}}}, selected_roles, with, without)
    assert_equal({}, with)
    assert_equal({}, without)

    assert_equal [users(:rahim).id], admin_view.process_connection_status_params!({mentor_recommendations: {mentees: "1"}, advanced_options: {mentor_recommendations: { mentees: {request_duration: "2", "1" => "", "2" => "01/01/2055",  "3" => ""}}}}, selected_roles, with, without)
    assert_equal({}, with)
    assert_equal({}, without)

    assert_equal [users(:rahim).id], admin_view.process_connection_status_params!({mentor_recommendations: {mentees: "1"}, advanced_options: {mentor_recommendations: { mentees: {request_duration: "3", "1" => "", "2" => "01/01/1985",  "3" => ""}}}}, selected_roles, with, without)
    assert_equal({}, with)
    assert_equal({}, without)
  end

  def test_process_advanced_connection_status_filters_program
    selected_roles = RoleConstants::DEFAULT_ROLE_NAMES.join(",")
    admin_view = programs(:albers).admin_views.first

    with = {}
    without = {}
    admin_view.process_connection_status_params!({}, selected_roles, with, without)
    assert_equal({}, with)

    programs(:albers).enable_feature(FeatureName::CALENDAR, true)
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    programs(:albers).allow_mentoring_mode_change = Program::MENTORING_MODE_CONFIG::EDITABLE
    programs(:albers).save!

    admin_view.reload
    program = programs(:albers)

    admin_view.process_advanced_connection_status_filters!({status_filters: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED}}}, (with={}), program)
    assert_equal({:active_user_connections_count=>0..1000000000, :closed_user_connections_count=>0..1000000000, :total_user_connections_count=>0..0, :draft_connections_count=>0..1000000000}, with)

    admin_view.process_advanced_connection_status_filters!({status_filters: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::CURRENTLY_CONNECTED}}}, (with={}), program)
    assert_equal({:active_user_connections_count=>1..1000000000, :closed_user_connections_count=>0..1000000000, :total_user_connections_count=>0..1000000000, :draft_connections_count=>0..1000000000}, with)

    admin_view.process_advanced_connection_status_filters!({status_filters: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED}}}, (with={}), program)
    assert_equal({:active_user_connections_count=>0..0, :closed_user_connections_count=>0..1000000000, :total_user_connections_count=>0..1000000000, :draft_connections_count=>0..1000000000}, with)

    admin_view.process_advanced_connection_status_filters!({status_filters: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED}}}, (with={}), program)
    assert_equal({:active_user_connections_count=>1..1000000000, :closed_user_connections_count=>0..0, :total_user_connections_count=>0..1000000000, :draft_connections_count=>0..1000000000}, with)

    admin_view.process_advanced_connection_status_filters!({status_filters: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST}}}, (with={}), program)
    assert_equal({:active_user_connections_count=>0..1000000000, :closed_user_connections_count=>0..1000000000, :total_user_connections_count=>1..1000000000, :draft_connections_count=>0..1000000000}, with)

    admin_view.process_advanced_connection_status_filters!({status_filters: {
      status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS, AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::LESS_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 100},
      status_filter_1: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::GREATER_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 10},
      status_filter_2: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => "", AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 5},
      status_filter_5: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 25},
      status_filter_6: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 15},
      status_filter_7: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::DRAFTED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::LESS_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 10}
    }}, (with={}), program)
    assert_equal({:active_user_connections_count=>11..99, :closed_user_connections_count=>25..25, :total_user_connections_count=>15..15, :draft_connections_count=>0..9}, with)

    admin_view.process_advanced_connection_status_filters!({status_filters: {
      status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS, AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::LESS_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 100},
      status_filter_1: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::GREATER_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 10},
      status_filter_2: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => "", AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 5},
      status_filter_5: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 25},
      status_filter_6: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 15},
      status_filter_7: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::DRAFTED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::LESS_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 10}
    }}, (with={}), program)
    assert_equal({:active_user_connections_count=>11..99, :closed_user_connections_count=>25..25, :total_user_connections_count=>15..15, :draft_connections_count=>0..9}, with)

  end

  def test_process_advanced_connection_status_filters_organization
    selected_roles = RoleConstants::DEFAULT_ROLE_NAMES.join(",")
    admin_view = programs(:albers).organization.admin_views.first

    with = {}
    without = {}
    admin_view.process_connection_status_params!({}, selected_roles, with, without)
    assert_equal({}, with)

    admin_view.process_advanced_connection_status_filters!({connection_status: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED}}}, (with={}))
    assert_equal({:ongoing_engagements_count=>0..1000000000, :closed_engagements_count=>0..1000000000, :total_engagements_count=>0..0}, with)

    admin_view.process_advanced_connection_status_filters!({connection_status: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::CURRENTLY_CONNECTED}}}, (with={}))
    assert_equal({:ongoing_engagements_count=>1..1000000000, :closed_engagements_count=>0..1000000000, :total_engagements_count=>0..1000000000}, with)

    admin_view.process_advanced_connection_status_filters!({connection_status: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED}}}, (with={}))
    assert_equal({:ongoing_engagements_count=>0..0, :closed_engagements_count=>0..1000000000, :total_engagements_count=>0..1000000000}, with)

    admin_view.process_advanced_connection_status_filters!({connection_status: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED}}}, (with={}))
    assert_equal({:ongoing_engagements_count=>1..1000000000, :closed_engagements_count=>0..0, :total_engagements_count=>0..1000000000}, with)

    admin_view.process_advanced_connection_status_filters!({connection_status: {status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST}}}, (with={}))
    assert_equal({:ongoing_engagements_count=>0..1000000000, :closed_engagements_count=>0..1000000000, :total_engagements_count=>1..1000000000}, with)

    admin_view.process_advanced_connection_status_filters!({connection_status: {
      status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS, AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::LESS_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 100},
      status_filter_1: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::GREATER_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 10},
      status_filter_2: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => "", AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 5},
      status_filter_5: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 25},
      status_filter_6: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 15}
    }}, (with={}))
    assert_equal({:ongoing_engagements_count=>11..99, :closed_engagements_count=>25..25, :total_engagements_count=>15..15}, with)

    admin_view.process_advanced_connection_status_filters!({connection_status: {
      status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS, AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::LESS_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 100},
      status_filter_1: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::GREATER_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 10},
      status_filter_2: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => "", AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 5},
      status_filter_5: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 25},
      status_filter_6: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => "", AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::EQUALS_TO, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 15}
    }}, (with={}))
    assert_equal({:ongoing_engagements_count=>11..99, :closed_engagements_count=>25..25, :total_engagements_count=>15..15}, with)
  end

  def test_programs_type_hash
    assert_equal_hash({AdminView::ConnectionStatusTypeKey::ONGOING => :active_user_connections_count, AdminView::ConnectionStatusTypeKey::CLOSED =>:closed_user_connections_count, AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED => :total_user_connections_count}, AdminView.programs_type_hash)
  end

  def test_organization_type_hash
    assert_equal_hash({AdminView::ConnectionStatusTypeKey::ONGOING => :ongoing_engagements_count, AdminView::ConnectionStatusTypeKey::CLOSED => :closed_engagements_count, AdminView::ConnectionStatusTypeKey::ONGOING_OR_CLOSED => :total_engagements_count}, AdminView.organization_type_hash)
  end

  def test_programs_category_hash
    assert_equal_hash({AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED => :total_user_connections_count_max, AdminView::ConnectionStatusCategoryKey::CURRENTLY_CONNECTED =>:active_user_connections_count_min, AdminView::ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED => :active_user_connections_count_max, AdminView::ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED => [:closed_user_connections_count_max, :active_user_connections_count_min], AdminView::ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST => :total_user_connections_count_min}, AdminView.programs_category_hash)
  end

  def test_organization_category_hash
    assert_equal_hash({AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED => :total_engagements_count_max, AdminView::ConnectionStatusCategoryKey::CURRENTLY_CONNECTED =>:ongoing_engagements_count_min, AdminView::ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED => :ongoing_engagements_count_max, AdminView::ConnectionStatusCategoryKey::FIRST_TIME_CONNECTED => [:closed_engagements_count_max, :ongoing_engagements_count_min], AdminView::ConnectionStatusCategoryKey::CONNECTED_CURRENTLY_OR_PAST => :total_engagements_count_min}, AdminView.organization_category_hash)
  end

  def test_get_category_hash_key
    category = AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED
    program_lvl = true
    assert_equal :total_user_connections_count_max, AdminView.get_category_hash_key(category, program_lvl)

    program_lvl = false
    assert_equal :total_engagements_count_max, AdminView.get_category_hash_key(category, program_lvl)
  end

  def test_get_type_hash_key
    type = AdminView::ConnectionStatusTypeKey::ONGOING
    program_lvl = true
    assert_equal :active_user_connections_count, AdminView.get_type_hash_key(type, program_lvl)

    program_lvl = false
    assert_equal :ongoing_engagements_count, AdminView.get_type_hash_key(type, program_lvl)
  end

  def test_process_connection_status_params_if_ongoing_mentoring_disabled
    selected_roles = RoleConstants::DEFAULT_ROLE_NAMES.join(",")
    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    admin_view = programs(:albers).admin_views.first
    with = {}
    without = {}
    admin_view.process_connection_status_params!({:status => UsersIndexFilters::Values::CONNECTED}, selected_roles, with, without)
    assert_equal({}, with)

    with = {}
    admin_view.process_connection_status_params!({:status => UsersIndexFilters::Values::UNCONNECTED}, selected_roles, with, without)
    assert_equal({}, with)

    with = {}
    admin_view.process_connection_status_params!({:last_closed_connection => {:type => AdminView::TimelineQuestions::Type::BEFORE_X_DAYS, :days => 5}}, selected_roles, with, without)
    assert_equal({}, with)
  end

  def test_last_connection
    Timecop.freeze do
      admin_view = programs(:albers).admin_views.first
      selected_roles = RoleConstants::DEFAULT_ROLE_NAMES.join(",")

      with = {}
      without = {}
      admin_view.process_connection_status_params!({last_closed_connection: {type: AdminView::TimelineQuestions::Type::BEFORE_X_DAYS, days: 12, date: "", date_range: ""}}, RoleConstants::ADMIN_NAME, with, without)
      assert_false with.keys.include?(:latest_closed_group_time)

      with = {}
      without = {}
      admin_view.process_connection_status_params!({last_closed_connection: {type: AdminView::TimelineQuestions::Type::BEFORE_X_DAYS, days: 12, date: "", date_range: ""}}, RoleConstants::STUDENT_NAME, with, without)
      assert with.keys.include?(:last_closed_group_time)
      assert_equal with[:last_closed_group_time].last, (Date.today - 12.days + 1.day).to_time

      assert_raise ArgumentError do
        admin_view.process_connection_status_params!({last_closed_connection: {type: AdminView::TimelineQuestions::Type::AFTER, days: 12, date: "", date_range: ""}}, selected_roles, with, without)
      end

      assert_raise ArgumentError do
        admin_view.process_connection_status_params!({last_closed_connection: {type: AdminView::TimelineQuestions::Type::BEFORE, days: 12, date: "", date_range: ""}}, selected_roles, with, without)
      end


      admin_view.process_connection_status_params!({last_closed_connection: {type: AdminView::TimelineQuestions::Type::DATE_RANGE, days: 12, date: "",
          date_range: ""}}, selected_roles, with, without)

      assert_nil with[:last_closed_group_time]

      date = (1.week.ago.to_date).strftime("time.formats.date_range".translate)
      admin_view.process_connection_status_params!({last_closed_connection: {type: AdminView::TimelineQuestions::Type::AFTER, days: 12, :date => date, date_range: ""}}, RoleConstants::MENTOR_NAME, with, without)
      assert with.keys.include?(:last_closed_group_time)
      assert_equal ( 1.week.ago + 1.day).to_date, with[:last_closed_group_time].first.to_date

      admin_view.process_connection_status_params!({last_closed_connection: {type: AdminView::TimelineQuestions::Type::BEFORE, days: 12, date: date, date_range: ""}}, selected_roles, with, without)
      assert with.keys.include?(:last_closed_group_time)
      assert_equal with[:last_closed_group_time].last.to_date, 1.week.ago.to_date

      admin_view.process_connection_status_params!({last_closed_connection: {type: AdminView::TimelineQuestions::Type::DATE_RANGE, days: 12, date: "", date_range: "#{date} - #{(2.days.from_now.to_date).strftime("time.formats.date_range".translate)}"}}, selected_roles, with, without)
      assert with.keys.include?(:last_closed_group_time)
      assert_equal 1.week.ago.to_date, with[:last_closed_group_time].first.to_date
      assert_equal (2.days.from_now + 1.day).to_date, with[:last_closed_group_time].last.to_date
    end
  end

  def test_apply_non_search_filters_with_profile
    admin_view = programs(:albers).admin_views.first

    user_ids = [users(:f_admin).id, users(:f_mentor).id, users(:f_student).id]
    user_ids = admin_view.apply_non_search_filters!(user_ids, {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}})

    assert_equal [users(:f_mentor).id], user_ids

    user_ids = [users(:f_admin).id, users(:f_mentor).id, users(:f_student).id]
    user_ids = admin_view.apply_non_search_filters!(user_ids, {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s, :value => ""}}})
    assert_equal_unordered [users(:f_admin).id, users(:f_student).id], user_ids

    user_ids = [users(:f_admin).id, users(:f_mentor).id, users(:f_student).id]
    assert_equal [users(:f_mentor).id], admin_view.apply_non_search_filters!(user_ids, {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "india"}}})
    assert_equal [users(:f_mentor).id], admin_view.apply_non_search_filters!(user_ids, {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "tamil nadu, india"}}})
    assert_equal [users(:f_mentor).id], admin_view.apply_non_search_filters!(user_ids, {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "chennai, tamil nadu, india"}}})
    assert_equal [users(:f_admin).id, users(:f_student).id], admin_view.apply_non_search_filters!(user_ids, {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value => "india"}}})
    assert_equal [users(:f_admin).id, users(:f_student).id], admin_view.apply_non_search_filters!(user_ids, {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value => "tamil nadu, india"}}})
    assert_equal [users(:f_admin).id, users(:f_student).id], admin_view.apply_non_search_filters!(user_ids, {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, :value => "chennai, tamil nadu, india"}}})
  end

  def test_apply_mandatory_profile_question_filter
    program = programs(:albers)
    organization = program.organization

    mentor_role = program.roles.find { |r| r.name == RoleConstants::MENTOR_NAME }
    mentee_role = program.roles.find { |r| r.name == RoleConstants::STUDENT_NAME }

    mentor_only_user1, mentor_only_user2 = program.users.select { |u| u.roles == [mentor_role] }[0..1]
    mentee_only_user1, mentee_only_user2 = program.users.select { |u| u.roles == [mentee_role] }[0..1]
    both_role_user1,   both_role_user2   = program.users.select { |u| u.role_names.sort == [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME] }[0..1]
    if both_role_user2.nil?
      both_role_user2 = program.users.select { |u| u.roles == [mentor_role] }[2]
      both_role_user2.roles = [mentor_role, mentee_role]
    end

    organization.profile_questions.destroy_all
    section = organization.sections.first
    mandatory_mentor_pq = organization.profile_questions.create!(section_id: section.id, question_text: "mandatory mentor question", question_type: ProfileQuestion::Type::STRING)
    mandatory_mentee_pq = organization.profile_questions.create!(section_id: section.id, question_text: "mandatory mentee question", question_type: ProfileQuestion::Type::STRING)
    mandatory__both__pq = organization.profile_questions.create!(section_id: section.id, question_text: "mandatory  both  question", question_type: ProfileQuestion::Type::STRING)
    optional_mentor_pq = organization.profile_questions.create!(section_id: section.id, question_text: "optional mentor question", question_type: ProfileQuestion::Type::STRING)
    optional_mentee_pq = organization.profile_questions.create!(section_id: section.id, question_text: "optional mentee question", question_type: ProfileQuestion::Type::STRING)
    optional__both__pq = organization.profile_questions.create!(section_id: section.id, question_text: "optional  both  question", question_type: ProfileQuestion::Type::STRING)
    admin_only_edit_pq = organization.profile_questions.create!(section_id: section.id, question_text: "admin only edit question", question_type: ProfileQuestion::Type::STRING)
    private_pq = organization.profile_questions.create!(section_id: section.id, question_text: "private question", question_type: ProfileQuestion::Type::STRING)

    mandatory_mentor_pq.role_questions.create!(role_id: mentor_role.id, required: true)
    mandatory_mentee_pq.role_questions.create!(role_id: mentee_role.id, required: true)
    mandatory__both__pq.role_questions.create!(role_id: mentor_role.id, required: true)
    mandatory__both__pq.role_questions.create!(role_id: mentee_role.id, required: true)
    optional_mentor_pq.role_questions.create!(role_id: mentor_role.id)
    optional_mentee_pq.role_questions.create!(role_id: mentee_role.id)
    optional__both__pq.role_questions.create!(role_id: mentor_role.id)
    optional__both__pq.role_questions.create!(role_id: mentee_role.id)
    admin_only_edit_pq.role_questions.create!(role_id: mentor_role.id, admin_only_editable: true)
    admin_only_edit_pq.role_questions.create!(role_id: mentee_role.id, admin_only_editable: true)
    private_pq.role_questions.create!(role_id: mentor_role.id, private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    private_pq.role_questions.create!(role_id: mentee_role.id, private: RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)

    [mandatory_mentor_pq, mandatory__both__pq, optional_mentor_pq, optional__both__pq].each do |profile_question|
      mentor_only_user1.member.profile_answers.create!(profile_question_id: profile_question.id, answer_text: "some string")
    end
    [mandatory_mentee_pq, mandatory__both__pq, optional_mentee_pq, optional__both__pq].each do |profile_question|
      mentee_only_user1.member.profile_answers.create!(profile_question_id: profile_question.id, answer_text: "some string")
    end
    [mandatory_mentor_pq, optional_mentor_pq, mandatory_mentee_pq, mandatory__both__pq, optional_mentee_pq, optional__both__pq].each do |profile_question|
      both_role_user1.member.profile_answers.create!(profile_question_id: profile_question.id, answer_text: "some string")
    end

    [mandatory_mentor_pq, mandatory__both__pq].each do |profile_question|
      mentor_only_user2.member.profile_answers.create!(profile_question_id: profile_question.id, answer_text: "some string")
    end
    [mandatory_mentee_pq, mandatory__both__pq].each do |profile_question|
      mentee_only_user2.member.profile_answers.create!(profile_question_id: profile_question.id, answer_text: "some string")
    end
    [mandatory_mentor_pq, mandatory_mentee_pq, mandatory__both__pq].each do |profile_question|
      both_role_user2.member.profile_answers.create!(profile_question_id: profile_question.id, answer_text: "some string")
    end

    user_ids = [mentor_only_user1, mentor_only_user2, mentee_only_user1, mentee_only_user2, both_role_user1, both_role_user2].map(&:id).sort
    admin_view = program.admin_views.last
    assert_equal_unordered [mentee_only_user1.id,  both_role_user1.id, mentor_only_user1.id], admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::FILLED_ALL_QUESTIONS)
    assert_equal_unordered user_ids - [mentee_only_user1.id,  both_role_user1.id, mentor_only_user1.id], admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_QUESTIONS)
    assert_equal_unordered user_ids, admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::FILLED_ALL_MANDATORY_QUESTIONS)
    assert_equal_unordered [], admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_MANDATORY_QUESTIONS)

    user_ids = program.users.pluck(:id)
    all_filled_user_ids = [mentor_only_user1, mentee_only_user1, both_role_user1, users(:f_admin), users(:f_user)].map(&:id)
    mandatory_filled_user_ids = all_filled_user_ids + [mentor_only_user2, mentee_only_user2, both_role_user2].map(&:id)
    assert_equal_unordered all_filled_user_ids, admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::FILLED_ALL_QUESTIONS)
    assert_equal_unordered user_ids - all_filled_user_ids, admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_QUESTIONS)
    assert_equal_unordered mandatory_filled_user_ids, admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::FILLED_ALL_MANDATORY_QUESTIONS)
    assert_equal_unordered user_ids - mandatory_filled_user_ids, admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_MANDATORY_QUESTIONS)
  end

  def test_apply_mandatory_profile_question_filter_for_conditional_questions
    program = programs(:albers)
    organization = program.organization

    organization.profile_questions.destroy_all

    mentor_role = program.roles.find { |r| r.name == RoleConstants::MENTOR_NAME }
    mentee_role = program.roles.find { |r| r.name == RoleConstants::STUDENT_NAME }

    parent_question = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "parent question", question_choices: ["A", "B", "C"], organization: programs(:org_primary))
    create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: parent_question, required: true)
    create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: parent_question, required: true)

    child_question_1 =  create_profile_question(question_text: "child question 1", question_type: ProfileQuestion::Type::STRING, conditional_question_id: parent_question.id, conditional_match_text: "A")
    create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: child_question_1, required: true)

    child_question_2 =  create_profile_question(question_text: "child question 1", question_type: ProfileQuestion::Type::STRING, conditional_question_id: parent_question.id, conditional_match_text: "B")
    create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: child_question_2, required: true)


    mentor_only_user1, mentor_only_user2 = program.users.select { |u| u.roles == [mentor_role] }[0..1]
    mentee_only_user1, mentee_only_user2 = program.users.select { |u| u.roles == [mentee_role] }[0..1]

    pa1 = mentor_only_user1.member.profile_answers.create!( answer_text: "A", profile_question: parent_question)
    pa1.answer_value = ["A"]
    pa1.save!
    mentor_only_user1.member.profile_answers.create!(profile_question_id: child_question_1.id, answer_text: "some string")

    pa2 = mentor_only_user2.member.profile_answers.create!( answer_text: "A", profile_question: parent_question)
    pa2.answer_value = ["A"]
    pa2.save!

    pa3 = mentee_only_user1.member.profile_answers.create!( answer_text: "B", profile_question: parent_question)
    pa3.answer_value = ["B"]
    pa3.save!
    mentee_only_user1.member.profile_answers.create!(profile_question_id: child_question_2.id, answer_text: "some string")

    pa3 = mentee_only_user2.member.profile_answers.create!( answer_text: "A", profile_question: parent_question)
    pa3.answer_value = ["A"]
    pa3.save!

    user_ids = [mentor_only_user1, mentor_only_user2, mentee_only_user1, mentee_only_user2].map(&:id).sort
    admin_view = program.admin_views.last

    assert_equal_unordered [mentor_only_user1, mentee_only_user1, mentee_only_user2].map(&:id).sort, admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::FILLED_ALL_MANDATORY_QUESTIONS)
    assert_equal_unordered [mentor_only_user2.id], admin_view.apply_mandatory_profile_question_filter(user_ids, AdminView::MandatoryFilterOptions::NOT_FILLED_ALL_MANDATORY_QUESTIONS)
  end

  def test_match_report_admin_views
    program = programs(:albers)
    admin_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTEES)
    admin_view_1 = program.admin_views.find_by(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES)
    assert_equal 1, admin_view.match_report_admin_views.count

    program.match_report_admin_views.find_by(admin_view: admin_view_1).update_attributes!(admin_view: admin_view)
    assert_equal 2, admin_view.reload.match_report_admin_views.count
  end

  def test_apply_non_search_filters_with_profile_scores
    admin_view = programs(:albers).admin_views.first

    user_ids = [users(:f_admin).id, users(:f_mentor).id, users(:f_student).id]

    ids = admin_view.apply_non_search_filters!(user_ids, {:score => {:value => "50", :operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s}, :questions => {:question_1 => {:operator => "", :question => "", :value => ""}}})
    assert_equal_unordered [users(:f_admin).id, users(:f_student).id], ids

    ids = admin_view.apply_non_search_filters!(user_ids, {:score => {:value => "50", :operator => AdminViewsHelper::QuestionType::HAS_GREATER_THAN.to_s}, :questions => {:question_1 => {:operator => "", :question => "", :value => ""}}})
    assert_equal [users(:f_mentor).id], ids
  end

  def test_apply_survey_filters_with_user_survey_response_status
    admin_view = programs(:albers).admin_views.first

    user_ids = [users(:f_admin).id, users(:f_mentor).id, users(:f_student).id]
    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name),common_questions(:q2_location),common_questions(:q2_from)
    survey_response = Survey::SurveyResponse.new(survey, {:user_id => users(:f_student).id})
    r_id = SurveyAnswer.unscoped.maximum(:response_id).to_i+1

    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})
    ids = admin_view.apply_survey_filters!(user_ids, {:user=>{:survey_id => survey.id.to_s, :users_status => "1"}, :survey_questions=>{:questions_1 =>{:survey_id => "", :question => "", :operator => "", :value => "", :choice => ""}}})
    assert_equal_unordered ids, [users(:f_student).id]

    ids = admin_view.apply_survey_filters!(user_ids, {:user=>{:survey_id => survey.id.to_s, :users_status => "0"}, :survey_questions=>{:questions_1 =>{:survey_id => "", :question => "", :operator => "", :value => "", :choice => ""}}})
    assert_equal_unordered ids, [users(:f_admin).id, users(:f_mentor).id]

    ids = admin_view.apply_survey_filters!(user_ids, {:user=>{:survey_id => "1111111", :users_status => "0"}, :survey_questions=>{:questions_1 =>{:survey_id => "", :question => "", :operator => "", :value => "", :choice => ""}}})
    assert_equal_unordered user_ids, ids

    survey_response2 = Survey::SurveyResponse.new(survey, {:user_id => users(:f_mentor).id})
    r_id = SurveyAnswer.unscoped.maximum(:response_id).to_i+1

    survey_response2.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})
    ids = admin_view.apply_survey_filters!(user_ids, {:user=>{:survey_id => survey.id.to_s, :users_status => "1"}, :survey_questions=>{:questions_1 =>{:survey_id => "", :question => "", :operator => "", :value => "", :choice => ""}}})
    assert_equal_unordered ids, [users(:f_student).id, users(:f_mentor).id]
  end

  def test_apply_survey_filters_with_user_survey_response_value
    admin_view = programs(:no_mentor_request_program).admin_views.first
    user_ids = [users(:no_mreq_mentor).id, users(:no_mreq_student).id]
    survey = surveys(:progress_report)
    q1,q2 = common_questions(:q3_name), common_questions(:q3_from)
    ids = admin_view.apply_survey_filters!(user_ids, {:user=>{:survey_id => "", :users_status => ""}, :survey_questions=>{:questions_1 =>{:survey_id => survey.id.to_s, :question => "answers#{q2.id}", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "", :choice => question_choices(:q3_from_3).id.to_s}}})
    assert_equal ids, [users(:no_mreq_student).id]

    ids = admin_view.apply_survey_filters!(user_ids, {:user=>{:survey_id => "", :users_status => ""}, :survey_questions=>{:questions_1 =>{:survey_id => survey.id.to_s, :question => "answers#{q2.id}", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "", :choice => question_choices(:q3_from_1).id.to_s}}})
    assert_equal ids, [users(:no_mreq_mentor).id]

    ids = admin_view.apply_survey_filters!(user_ids, {:user=>{:survey_id => "", :users_status => ""}, :survey_questions=>{:questions_1 =>{:survey_id => survey.id.to_s, :question => "answers#{q2.id}", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "", :choice => question_choices(:q3_from_3).id.to_s}, :questions_2 =>{:survey_id => survey.id.to_s, :question => "answers#{q2.id}", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "", :choice => question_choices(:q3_from_1).id.to_s}}})
    assert_equal_unordered ids, []

    ids = admin_view.apply_survey_filters!(user_ids, {:user=>{:survey_id => "", :users_status => ""}, :survey_questions=>{:questions_1 =>{:survey_id => survey.id.to_s, :question => "answers#{q1.id}", :operator => AdminViewsHelper::QuestionType::WITH_VALUE.to_s, :value => "remove", :choice => ""}}})
    assert_equal_unordered ids, user_ids
  end

  def test_default_views_create_for
    program = programs(:albers)
    assert_no_difference "AdminView.count" do
      AdminView::DefaultViews.create_for(program)
    end

    program.abstract_views.where(type: "AdminView").destroy_all
    program.stubs(:create_views_related_to_drafted_connections?).returns(true)
    assert_difference "AdminView.count", 17 do
      AdminView::DefaultViews.create_for(program)
    end
    accepted_not_signed_up = program.abstract_views.where(default_view: AbstractView::DefaultType::ACCEPTED_BUT_NOT_JOINED).first
    registered_not_active = program.abstract_views.where(default_view: AbstractView::DefaultType::REGISTERED_BUT_NOT_ACTIVE).first
    never_connected_mentees = program.abstract_views.where(default_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTEES).first
    never_connected_mentors = program.abstract_views.where(default_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTORS).first
    currently_not_connected_users = program.abstract_views.where(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES).first
    users_with_low_profile_scores = program.abstract_views.where(default_view: AbstractView::DefaultType::USERS_WITH_LOW_PROFILE_SCORES).first
    available_mentors = program.abstract_views.where(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS).first

    mentors_registered_but_not_active = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE).first
    mentees_registered_but_not_active = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE).first
    mentors_with_low_profile_score = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES).first
    mentees_with_low_profile_score = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES).first
    mentors_in_drafted_connections = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS).first
    mentees_in_drafted_connections = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS).first
    mentors_yet_to_be_drafted = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED).first
    mentees_yet_to_be_drafted = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED).first
    mentors_with_pending_mentor_requests = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS).first
    mentees_who_sent_request_but_not_connected = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED).first
    mentees_who_havent_sent_mentoring_request = program.abstract_views.where(default_view: AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST).first

    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, 'user']}, "signup_state"=>{"accepted_not_signed_up_users"=>"#{AdminView::RolesStatusQuestions::ACCEPTED_NOT_SIGNED_UP}"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => "", "mentoring_requests" => {"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, accepted_not_signed_up.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state" => {"active" => "active"}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => "", "mentoring_requests" => {"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, never_connected_mentees.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state" => {"active" => "active"}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>AdminView::ConnectionStatusCategoryKey::NEVER_CONNECTED}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => "", "mentoring_requests" => {"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, never_connected_mentors.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state" => {"active" => "active"}}, "connection_status"=>{"availability"=>{"operator"=>AdminViewsHelper::QuestionType::HAS_GREATER_THAN.to_s, "value"=>"0"}, "meetingconnection_status" => "", "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, available_mentors.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state" => {"active" => "active"}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>AdminView::ConnectionStatusCategoryKey::CURRENTLY_UNCONNECTED}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status" => "", "mentoring_requests" => {"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, currently_not_connected_users.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=>{"pending"=>"pending"}, "signup_state"=>{"signed_up_users"=>"signed_up_users"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status"=>"", "mentoring_requests"=>{"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentors_registered_but_not_active.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=>{"pending"=>"pending"}, "signup_state"=>{"signed_up_users"=>"signed_up_users"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status"=>"", "mentoring_requests"=>{"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentees_registered_but_not_active.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=>{"active"=>"active"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "last_closed_connection"=>{"type"=>"", "days"=>"", "date"=>"", "date_range"=>""}, "meetingconnection_status"=>"", "mentoring_requests"=>{"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"1", "value"=>"80"}}, "others"=>{"tags"=>""}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentors_with_low_profile_score.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=>{"active"=>"active"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "last_closed_connection"=>{"type"=>"", "days"=>"", "date"=>"", "date_range"=>""}, "meetingconnection_status"=>"", "mentoring_requests"=>{"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"1", "value"=>"80"}}, "others"=>{"tags"=>""}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentees_with_low_profile_score.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=>{"active"=>"active", "pending"=>"pending"}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>"advanced_filters", "type"=>"drafted", "operator"=>"greater_than", "countvalue"=>0}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status"=>"", "mentoring_requests"=>{"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentors_in_drafted_connections.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=>{"active"=>"active", "pending"=>"pending"}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>"advanced_filters", "type"=>"drafted", "operator"=>"greater_than", "countvalue"=>0}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status"=>"", "mentoring_requests"=>{"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentees_in_drafted_connections.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=>{"active"=>"active", "pending"=>"pending"}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>"advanced_filters", "type"=>"drafted", "operator"=>"equals_to", "countvalue"=>0}, "status_filter_2"=>{"category"=>"", "type"=>"ongoing", "operator"=>"equals_to", "countvalue"=>0}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status"=>"", "mentoring_requests"=>{"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentors_yet_to_be_drafted.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=>{"active"=>"active", "pending"=>"pending"}}, "connection_status"=>{"status_filters"=>{"status_filter_1"=>{"category"=>"advanced_filters", "type"=>"drafted", "operator"=>"equals_to", "countvalue"=>0}, "status_filter_2"=>{"category"=>"", "type"=>"ongoing", "operator"=>"equals_to", "countvalue"=>0}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status"=>"", "mentoring_requests"=>{"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentees_yet_to_be_drafted.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::MENTOR_NAME]}, "state"=>{"active"=>"active"}}, "connection_status"=>{"mentoring_requests"=>{"mentors"=>2}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status"=>"", "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentors_with_pending_mentor_requests.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=>{"active"=>"active"}}, "connection_status"=>{"mentoring_requests"=>{"mentees"=>1}, "status_filters"=>{"status_filter_1"=>{"category"=>"never_connected"}}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status"=>"", "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentees_who_sent_request_but_not_connected.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::STUDENT_NAME]}, "state"=>{"active"=>"active"}}, "connection_status"=>{"mentoring_requests"=>{"mentees"=>3}, "availability"=>{"operator"=>"", "value"=>""}, "meetingconnection_status"=>"", "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"", "value"=>""}}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, mentees_who_havent_sent_mentoring_request.filter_params_hash)
    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, 'user']}, "state"=>{"active"=>"active"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "last_closed_connection"=>{"type"=>"", "days"=>"", "date"=>"", "date_range"=>""}, "meetingconnection_status" => "", "mentoring_requests" => {"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"1", "value"=>"60"}}, "others"=>{"tags"=>""}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, users_with_low_profile_scores.filter_params_hash)
  end

  def test_create_for_portal
    program = programs(:primary_portal)
    program.admin_views.destroy_all
    assert_difference 'AdminView.count', 1 do
      AdminView::DefaultViews.create_for(program)
    end
    users_with_low_profile_scores = program.abstract_views.where(default_view: AbstractView::DefaultType::USERS_WITH_LOW_PROFILE_SCORES).first

    assert_equal_hash({"roles_and_status"=>{"role_filter_1"=>{"type"=>"include", "roles"=>[RoleConstants::ADMIN_NAME, RoleConstants::EMPLOYEE_NAME]},"state"=>{"active"=>"active"}}, "connection_status"=>{"availability"=>{"operator"=>"", "value"=>""}, "last_closed_connection"=>{"type"=>"", "days"=>"", "date"=>"", "date_range"=>""}, "meetingconnection_status" => "", "mentoring_requests" => {"mentees"=>"", "mentors"=>""}, "meeting_requests"=>{"mentees"=>"", "mentors"=>""}}, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"", "operator"=>"", "value"=>""}}, "score"=>{"operator"=>"1", "value"=>"60"}}, "others"=>{"tags"=>""}, "timeline"=>{"timeline_questions"=>{"questions_1"=>{"question"=>"", "type"=>"", "value"=>""}}}}, users_with_low_profile_scores.filter_params_hash)
  end

  def test_sort_users
    admin_view = programs(:albers).admin_views.first

    assert_equal [], admin_view.sort_users_or_members([], "first_name", "desc", User, {})

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)

    user_ids = [f_admin.id, f_mentor.id, f_student.id]

    question = profile_questions(:profile_questions_4)
    admin_view_column = admin_view.admin_view_columns.create!(profile_question: question)

    f_admin.save_answer!(question, '044-213-57-52')
    f_mentor.save_answer!(question, '044-213-57-56')
    f_student.save_answer!(question, '044-213-55-52')

    assert_equal [f_student, f_admin, f_mentor].collect(&:id), admin_view.sort_users_or_members(user_ids, "column#{admin_view_column.id}", "asc", User, {})
    assert_equal [f_mentor, f_admin, f_student].collect(&:id), admin_view.sort_users_or_members(user_ids, "column#{admin_view_column.id}", "desc", User, {})
  end

  def test_sort_users_scoped_location_fields
    admin_view = programs(:albers).admin_views.first
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    user_ids = [f_admin.id, f_mentor.id, f_student.id]

    question = programs(:albers).profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], {skype: false, default: false}).select{|pq| pq.location?}.first
    admin_view_column = admin_view.admin_view_columns.create!(profile_question: question, column_sub_key: "state")
    locations = Location.reliable.all

    f_admin.save_answer!(question, locations[0].full_address)
    f_mentor.save_answer!(question, locations[1].full_address)
    f_student.save_answer!(question, locations[2].full_address)

    # delhi, pondichery, tamil nadu : order, but full address is in different order
    assert_equal [f_mentor, f_student, f_admin].collect(&:id), admin_view.sort_users_or_members(user_ids, "column#{admin_view_column.id}", "asc", User, {})
    assert_equal [f_admin, f_student, f_mentor].collect(&:id), admin_view.sort_users_or_members(user_ids, "column#{admin_view_column.id}", "desc", User, {})
  end

  def test_sort_members_scoped_location_fields
    admin_view = programs(:org_primary).admin_views.first
    f_admin   = members(:f_admin)
    f_mentor  = members(:f_mentor)
    f_student = members(:f_mentor_student)
    member_ids = [f_admin.id, f_mentor.id, f_student.id]

    question = programs(:org_primary).profile_questions.select{|pq| pq.location?}.first
    admin_view_column = admin_view.admin_view_columns.create!(profile_question: question, column_sub_key: "state")
    locations = Location.reliable.all

    f_admin.save_answer!(question, locations[0].full_address)
    f_mentor.save_answer!(question, locations[1].full_address)
    f_student.save_answer!(question, locations[2].full_address)

    # delhi, pondichery, tamil nadu : order, but full address is in different order
    assert_equal [f_mentor, f_student, f_admin].collect(&:id), admin_view.sort_users_or_members(member_ids, "column#{admin_view_column.id}", "asc", Member, {})
    assert_equal [f_admin, f_student, f_mentor].collect(&:id), admin_view.sort_users_or_members(member_ids, "column#{admin_view_column.id}", "desc", Member, {})
  end

  def test_sort_members
    admin_view = programs(:org_primary).admin_views.first

    member_ids = [members(:f_admin).id, members(:f_mentor).id, members(:f_mentor_student).id]
    assert_equal [members(:f_mentor_student).id, members(:f_admin).id, members(:f_mentor).id], admin_view.sort_users_or_members(member_ids, "program_user_roles", "asc", Member, {})
    assert_equal [members(:f_admin).id, members(:f_mentor).id, members(:f_mentor_student).id], admin_view.sort_users_or_members(member_ids, "program_user_roles", "desc", Member, {})
  end

  def test_default
    default_admin_views = programs(:albers).admin_views.default.all
    default_admin_views.each do |default_admin_view|
      assert default_admin_view.default?
      # testing the overriden alias_method
      if AdminView::EDITABLE_DEFAULT_VIEWS.include?(default_admin_view.default_view)
        assert default_admin_view.editable?
      else
        assert_false default_admin_view.editable?
      end
      assert_false default_admin_view.non_default?

      editable_view = AdminView.create!(:program => programs(:albers), :title => "New Title " + default_admin_view.id.to_s, :filter_params => AdminView.convert_to_yaml({:roles_and_status => {role_filter_1: {type: :include}}}))

      assert_false editable_view.default?
      assert editable_view.editable?
    end
  end

  def test_defaults_first
    not_default = AdminView.create!(:program => programs(:albers), :title => "New Title", :filter_params => AdminView.convert_to_yaml({:roles_and_status => {role_filter_1: {type: :include}}}))
    admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS).update_column(:created_at, not_default.created_at + 1.day)

    assert_equal ['All Users', 'New Title'], AdminView.defaults_first.map(&:title).select{|title| title == 'New Title' || title == 'All Users'}.uniq
  end

  def test_timeline_filters_last_login_date
    admin_view = programs(:albers).admin_views.first
    with = {}
    parameters = {}
    without = {}
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({}, with)

    admin_view = programs(:albers).admin_views.first
    with = {}
    parameters[:timeline_questions] = {:question_1 => {:question => "223", :value => "9/5/2012 - 9/20/2027", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({}, with)

    with = {}
    parameters[:timeline_questions] = {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :value => "9/5/2012 - 9/20/2027", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    from = Date.strptime("9/5/2012", MeetingsHelper::DateRangeFormat.call).to_time
    to = Date.strptime("9/21/2027", MeetingsHelper::DateRangeFormat.call).to_time
    assert_equal({:last_seen_at => from..to}, with)

    with = {}
    parameters[:timeline_questions] = {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :value => "", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({}, with)

    with = {}
    parameters[:timeline_questions] = {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :value => "9/20/2027", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    from = Date.strptime("9/20/2027", MeetingsHelper::DateRangeFormat.call).to_time
    to = Date.strptime("9/21/2027", MeetingsHelper::DateRangeFormat.call).to_time
    assert_equal({:last_seen_at => from..to}, with)

    parameters[:timeline_questions] = {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :value => "Never", type: AdminView::TimelineQuestions::Type::NEVER}}
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({:multi_exists_query => [:last_seen_at]}, without)
  end

  def test_timeline_filters_last_deactivated_at
    admin_view = programs(:albers).admin_views.first
    with = {}
    without = {}
    parameters = {}

    with = {}
    parameters[:timeline_questions] = {:question_1 => {:question => AdminView::TimelineQuestions::LAST_DEACTIVATED_AT.to_s, :value => "9/5/2012 - 9/20/2027", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    from = Date.strptime("9/5/2012", MeetingsHelper::DateRangeFormat.call).to_time
    to = Date.strptime("9/21/2027", MeetingsHelper::DateRangeFormat.call).to_time
    assert_equal({:last_deactivated_at => from..to}, with)

    with = {}
    parameters[:timeline_questions] = {:question_1 => {:question => AdminView::TimelineQuestions::LAST_DEACTIVATED_AT.to_s, :value => "", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({}, with)

    with = {}
    parameters[:timeline_questions] = {:question_1 => {:question => AdminView::TimelineQuestions::LAST_DEACTIVATED_AT.to_s, :value => "9/20/2027", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    from = Date.strptime("9/20/2027", MeetingsHelper::DateRangeFormat.call).to_time
    to = Date.strptime("9/21/2027", MeetingsHelper::DateRangeFormat.call).to_time
    assert_equal({:last_deactivated_at => from..to}, with)
  end

  def test_timeline_daterange_intersection
    admin_view = programs(:albers).admin_views.first
    with = {}
    without = {}
    parameters = {}
    assert_equal({}, with)
    assert_equal "2", AdminView::TimelineQuestions::JOIN_DATE.to_s
    assert_equal "5", AdminView::TimelineQuestions::Type::DATE_RANGE.to_s
    assert_equal "3", AdminView::TimelineQuestions::Type::BEFORE_X_DAYS.to_s
    assert_equal "4", AdminView::TimelineQuestions::Type::AFTER.to_s
    assert_equal "6", AdminView::TimelineQuestions::Type::IN_LAST_X_DAYS.to_s

    with = {}
    parameters[:timeline_questions] = {
      question_1: {question: '2', value: "1/30/2012 - 11/23/2013", type: '5'},
      question_2: {question: '2', value: "3/30/2012 - 10/23/2013", type: '5'}
    }
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({created_at: Time.new(2012,3,30)..Time.new(2013,10,24)}, with)

    with = {}
    parameters[:timeline_questions] = {
      question_1: {question: '2', value: "1/30/2012 - 11/23/2013", type: '5'},
      question_2: {question: '2', value: "3/30/2012 - 10/23/2014", type: '5'}
    }
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({created_at: Time.new(2012,3,30)..Time.new(2013,11,24)}, with)

    with = {}
    parameters[:timeline_questions] = {
      question_1: {question: '2', value: "3/30/2012 - 4/30/2012", type: '5'},
      question_2: {question: '2', value: "1/30/2012 - 2/20/2012", type: '5'}
    }
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({created_at: 0}, with)

    Timecop.freeze(Time.new(2012, 5, 15)) do
      with = {}
      parameters[:timeline_questions] = {
        question_1: {question: '2', value: "3/30/2012", type: '4'},
        question_2: {question: '2', value: "10", type: '3'}
      }
      admin_view.process_timeline_params!(parameters, with, without)
      assert_equal({created_at: Time.new(2012,3,31)..Time.new(2012,5,6)}, with)
    end
  end

  def test_timeline_filters_accepted_tnc
    admin_view = programs(:albers).admin_views.first

    with = {}
    without = {}
    parameters = {}
    parameters[:timeline_questions] = {question_1: {question: AdminView::TimelineQuestions::TNC_ACCEPTED_ON.to_s, value: "9/5/2012 - 9/20/2027", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    from = Date.strptime("9/5/2012", MeetingsHelper::DateRangeFormat.call).to_time
    to = Date.strptime("9/21/2027", MeetingsHelper::DateRangeFormat.call).to_time
    assert_equal({"member.terms_and_conditions_accepted" => from..to}, with)

    with = {}
    parameters[:timeline_questions] = {question_1: {question: AdminView::TimelineQuestions::TNC_ACCEPTED_ON.to_s, value: "", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({}, with)

    with = {}
    parameters[:timeline_questions] = {question_1: {question: AdminView::TimelineQuestions::TNC_ACCEPTED_ON.to_s, value: "9/20/2027", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    from = Date.strptime("9/20/2027", MeetingsHelper::DateRangeFormat.call).to_time
    to = Date.strptime("9/21/2027", MeetingsHelper::DateRangeFormat.call).to_time
    assert_equal({"member.terms_and_conditions_accepted" => from..to}, with)
    assert_empty without

    parameters[:timeline_questions] = {:question_1 => {:question => AdminView::TimelineQuestions::TNC_ACCEPTED_ON.to_s, :value => "Never", type: AdminView::TimelineQuestions::Type::NEVER}, :question_2 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :value => "Never", type: AdminView::TimelineQuestions::Type::NEVER}}
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({:multi_exists_query => ["member.terms_and_conditions_accepted", :last_seen_at]}, without)
  end

  def test_timeline_filters_signed_up_on
    admin_view = programs(:albers).admin_views.first

    with = {}
    without = {}
    parameters = {}
    parameters[:timeline_questions] = {question_1: {question: AdminView::TimelineQuestions::SIGNED_UP_ON.to_s, value: "9/5/2012 - 9/20/2027", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    from = Date.strptime("9/5/2012", MeetingsHelper::DateRangeFormat.call).to_time
    to = Date.strptime("9/21/2027", MeetingsHelper::DateRangeFormat.call).to_time
    assert_equal({"first_activity.created_at" => from..to}, with)

    with = {}
    parameters[:timeline_questions] = {question_1: {question: AdminView::TimelineQuestions::SIGNED_UP_ON.to_s, value: "", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    assert_equal({}, with)

    with = {}
    parameters[:timeline_questions] = {question_1: {question: AdminView::TimelineQuestions::SIGNED_UP_ON.to_s, value: "9/20/2027", type: AdminView::TimelineQuestions::Type::DATE_RANGE}}
    admin_view.process_timeline_params!(parameters, with, without)
    from = Date.strptime("9/20/2027", MeetingsHelper::DateRangeFormat.call).to_time
    to = Date.strptime("9/21/2027", MeetingsHelper::DateRangeFormat.call).to_time
    assert_equal({"first_activity.created_at" => from..to}, with)
  end

  def test_older_than_range
    admin_view = programs(:albers).admin_views.first
    with = {}
    without = {}
    parameters = {}
    Timecop.freeze(Time.new(2000)) do
      parameters[:timeline_questions] = {question_1: {question: AdminView::TimelineQuestions::TNC_ACCEPTED_ON.to_s, value: "10", type: AdminView::TimelineQuestions::Type::BEFORE_X_DAYS.to_s}}
      admin_view.process_timeline_params!(parameters, with, without)
      from = Time.new(1985)
      to = Time.new(2000) - 9.days
      assert_equal({"member.terms_and_conditions_accepted" => from..to}, with)
    end
  end

  def test_in_last_x_range
    admin_view = programs(:albers).admin_views.first
    with = {}
    without = {}
    parameters = {}
    Timecop.freeze(Time.new(2000)) do
      parameters[:timeline_questions] = {question_1: {question: AdminView::TimelineQuestions::TNC_ACCEPTED_ON.to_s, value: "10", type: AdminView::TimelineQuestions::Type::IN_LAST_X_DAYS.to_s}}
      admin_view.process_timeline_params!(parameters, with, without)
      from = Time.new(2000) - 10.days
      to = Time.new(2500)
      assert_equal({"member.terms_and_conditions_accepted" => from..to}, with)
    end
  end

  def test_create_default_columns_for_program
    admin_view = AdminView.create!(program: programs(:albers), title: "New Title", filter_params: AdminView.convert_to_yaml(roles_and_status: { role_filter_1: { type: :include } } ))
    assert_difference "AdminViewColumn.count", 10 do
      admin_view.create_default_columns
    end
    assert_equal 9, admin_view.admin_view_columns.last.position
    assert_equal AdminViewColumn::Columns::Key::MEMBER_ID, admin_view.admin_view_columns.first.key
  end

  def test_create_default_columns_for_organization
    admin_view = AdminView.create!(program: programs(:org_primary), title: "New Title", filter_params: AdminView.convert_to_yaml({}))
    assert_difference "AdminViewColumn.count", 7 do
      admin_view.create_default_columns
    end
    assert_equal AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES, admin_view.admin_view_columns.last(2).first.key
    assert_equal AdminViewColumn::Columns::Key::LAST_SUSPENDED_AT, admin_view.admin_view_columns.last.key
  end

  def test_admin_view_columns_order
    admin_view = programs(:albers).admin_views.first
    assert_equal (0..9).to_a, admin_view.admin_view_columns.pluck(:position)

    column = admin_view.admin_view_columns.first
    assert_equal AdminViewColumn::Columns::Key::MEMBER_ID, column.key

    column.update_attributes!(position: 10)
    assert_equal (1..10).to_a, admin_view.admin_view_columns.pluck(:position)

    column = admin_view.admin_view_columns.last
    assert_equal AdminViewColumn::Columns::Key::MEMBER_ID, column.key
  end

  def test_save_admin_view_columns
    program = programs(:albers)
    admin_view = program.admin_views.first
    assert_equal 10, admin_view.admin_view_columns.size

    assert_difference "AdminViewColumn.count", -8 do
      admin_view.save_admin_view_columns!([AdminViewColumn::Columns::Key::FIRST_NAME, AdminViewColumn::Columns::Key::LAST_NAME])
    end
    assert_equal 2, admin_view.admin_view_columns.reload.size

    assert_difference "AdminViewColumn.count", 0 do
      admin_view.save_admin_view_columns!([AdminViewColumn::Columns::Key::FIRST_NAME, AdminViewColumn::Columns::Key::LAST_NAME])
    end
    assert_equal 2, admin_view.admin_view_columns.reload.size

    profile_question = program.profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], { skype: false, default: false } ).first
    assert_difference "AdminViewColumn.count", -1 do
      admin_view.save_admin_view_columns!(["#{profile_question.id}"])
    end
    assert_equal 1, admin_view.admin_view_columns.reload.size

    location_profile_question = program.profile_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], { skype: false, default: false } ).select { |pq| pq.location? }.first
    admin_view.save_admin_view_columns!(["#{location_profile_question.id}", "#{location_profile_question.id}-city"])
    assert_equal ["#{location_profile_question.id}", "#{location_profile_question.id}-city"], admin_view.admin_view_columns.reload.map(&:key)
    assert_equal 2, admin_view.admin_view_columns.size
  end

  def test_generate_csv_report_for_education_and_work_and_publication_and_manager_questions
    program = programs(:albers)
    users = program.users[0,2]
    admin_view = program.admin_views.first
    time_now = Time.now

    admin_view.admin_view_columns.destroy_all

    # education question
    q1 = profile_questions(:profile_questions_6)
    admin_view.admin_view_columns.create!(profile_question: q1, position: 0)
    create_education(users[0], q1)
    ed = create_education(users[0], q1, school_name: "KPI")
    ed.update_attribute(:graduation_year, nil)
    create_education(users[1], q1)

    # work question
    q2 = profile_questions(:profile_questions_7)
    admin_view.admin_view_columns.create!(profile_question: q2, position: 1)
    create_experience(users[0], q2)
    create_experience(users[1], q2)
    ex = create_experience(users[1], q2, job_title: "PM")
    ex.update_attribute(:end_year, nil)

    # publication question
    q3 = profile_questions(:publication_q)
    admin_view.admin_view_columns.create!(profile_question: q3, position: 1)
    travel_to(time_now - 9.hours) do
      pub = create_publication(users[0], q3)
      pub.save!
    end
    travel_to(time_now - 8.hours) do
      pub = create_publication(users[1], q3)
      pub.save!
    end
    travel_to(time_now - 10.hours) do
      pub = create_publication(users[1], q3, title: "Pub")
      pub.update_attribute(:year, nil)
      pub.save!
    end

    # manager question
    q4 = profile_questions(:manager_q)
    admin_view.admin_view_columns.create!(profile_question: q4, position: 1)
    create_manager(users[0], q4)
    pub = create_manager(users[1], q4, first_name: "Man1")
    pub.update_attribute(:email, 'mal@example.com')

    body = Enumerator.new do |stream|
      admin_view.reload.report_to_stream(stream, users.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(body.to_a.join)

    assert_equal 3, csv_array.size
    expected_headers = [
      "Education-College/School Name",
      "Education-Degree",
      "Education-Major",
      "Education-Graduation Year",
      "Education-College/School Name",
      "Education-Degree",
      "Education-Major",
      "Education-Graduation Year",
      "Work-Job Title",
      "Work-Start year",
      "Work-End year",
      "Work-Company/Institution",
      "Work-Job Title",
      "Work-Start year",
      "Work-End year",
      "Work-Company/Institution",
      "Current Publication-Title",
      "Current Publication-Publication/Publisher",
      "Current Publication-Publication Date",
      "Current Publication-Publication URL",
      "Current Publication-Author(s)",
      "Current Publication-Description",
      "Current Publication-Title",
      "Current Publication-Publication/Publisher",
      "Current Publication-Publication Date",
      "Current Publication-Publication URL",
      "Current Publication-Author(s)",
      "Current Publication-Description",
      "Current Manager-First name",
      "Current Manager-Last name",
      "Current Manager-Email"
    ]
    assert_equal expected_headers, csv_array[0]

    expected_data1 = [
      "SSV", "BTech", "IT", "2009",
      "KPI", "BTech", "IT", nil,
      "SDE", "2000", "2009", "MSFT",
      nil, nil, nil, nil, "Publication",
      "Publisher ltd.", "January 03, 2009",
      "http://public.url", "Author", "Very useful publication",
      nil, nil, nil, nil, nil, nil,
      "Manager", "Name", "manager@example.com"
    ]
    assert_equal expected_data1, csv_array[1]

    expected_data2 = [
      "SSV", "BTech", "IT", "2009",
      nil, nil, nil, nil,
      "SDE", "2000", "2009", "MSFT",
      "PM", "2000", nil, "MSFT",
      "Publication", "Publisher ltd.", "January 03, 2009",
      "http://public.url", "Author", "Very useful publication",
      "Pub", "Publisher ltd.", "", "http://public.url",
      "Author", "Very useful publication",
      "Man1", "Name", "mal@example.com"
    ]
    assert_equal expected_data2, csv_array[2]
  end

  def test_last_connection_column_report_to_stream
    program = programs(:albers)
    admin_view = program.admin_views.first
    users = program.users
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::LAST_CLOSED_GROUP_TIME, position: 9)
    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, users.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal (users.size + 1), csv_array.size
    assert_equal "Member ID,First Name,Last Name,Email,Roles,Status,Ongoing Mentoring Connections,Closed Mentoring Connections,Drafted Mentoring Connections,Joined On,Last Mentoring Connection Closed On".split(","), csv_array.first

    user = users(:student_1)
    group = user.groups.first
    group.terminate!(users(:f_admin), "check", program.permitted_closure_reasons.first.id)
    user.reload
    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, [user.id], admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal 2, csv_array.size
    assert_equal DateTime.localize(Time.now.utc), csv_array.last.last
  end

  def test_rating_column_report_to_stream
    program = programs(:albers)
    program.enable_feature(FeatureName::COACH_RATING, true)
    admin_view = program.admin_views.first
    users = program.users
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::RATING, position: 9)
    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, users.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal (users.size + 1), csv_array.size
    assert_equal "Member ID,First Name,Last Name,Email,Roles,Status,Ongoing Mentoring Connections,Closed Mentoring Connections,Drafted Mentoring Connections,Joined On,Rating".split(","), csv_array.first

    rated_mentor = users(:f_mentor)
    student = users(:f_student)
    unrated_mentor = users(:f_mentor_student)
    rating = 4
    UserStat.create!(user: rated_mentor, average_rating: rating, rating_count: 1)
    rated_mentor.reload
    users_id_list = [rated_mentor.id, student.id, unrated_mentor.id]
    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, users_id_list, admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal users_id_list.size + 1, csv_array.size
    assert_equal "4.0", csv_array[1].last
    assert_equal "NA", csv_array[2].last
    assert_equal "Not rated yet.", csv_array.last.last
  end

  def test_mentoring_mode_column_report_to_stream
    admin_view = programs(:albers).admin_views.create!(title: "Users with Mentoring Mode", filter_params: {sample_key: ""}.to_yaml)
    user_ids = [users(:f_mentor).id, users(:robert).id, users(:student_1).id, users(:student_6).id]
    admin_view.admin_view_columns.create!(column_key: "mentoring_mode")

    users(:f_mentor).update_attribute(:mentoring_mode, User::MentoringMode::ONGOING)
    users(:robert).update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    users(:student_1).update_attribute(:mentoring_mode, User::MentoringMode::NOT_APPLICABLE)
    assert_equal users(:student_6).mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING

    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, user_ids, admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal (user_ids.size + 1), csv_array.size
    assert_equal ["Mentoring Mode"], csv_array.first
    assert_equal ["Ongoing Mentoring"], csv_array[1]
    assert_equal ["One-time Mentoring"], csv_array[2]
    assert_equal ["NA"], csv_array[3]
    assert_equal ["Ongoing and One-time Mentoring"], csv_array[4]
  end

  def test_last_deactivated_at_to_stream
    admin_view = programs(:albers).admin_views.create!(title: "Users with Last deactivated at", filter_params: {sample_key: ""}.to_yaml)
    user_ids = [users(:f_mentor).id, users(:robert).id, users(:student_1).id, users(:student_6).id]
    admin_view.admin_view_columns.create!(column_key: "last_deactivated_at")

    day1 = DateTime.new(2017, 12, 12)
    day2 = DateTime.new(2017, 12, 13)
    day3 = DateTime.new(2017, 12, 14)
    users(:f_mentor).update_attribute(:last_deactivated_at, day1)
    users(:robert).update_attribute(:last_deactivated_at, day2)
    users(:student_1).update_attribute(:last_deactivated_at, day3)
    assert_nil users(:student_6).last_deactivated_at

    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, user_ids, admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal (user_ids.size + 1), csv_array.size
    assert_equal ["Last Deactivated On"], csv_array.first
    assert_equal [DateTime.localize(day1, format: :default_dashed)], csv_array[1]
    assert_equal [DateTime.localize(day2, format: :default_dashed)], csv_array[2]
    assert_equal [DateTime.localize(day3, format: :default_dashed)], csv_array[3]
    assert_equal ['feature.admin_view_column.content.never_deactivated'.translate], csv_array[4]

    organization_admin_view = AdminView.create!(program: programs(:org_primary), title: "Members with last suspended at", filter_params: AdminView.convert_to_yaml({}))
    organization_admin_view.admin_view_columns.create!(column_key: "last_suspended_at")
    member_ids = [members(:f_mentor).id, members(:robert).id, members(:student_1).id, members(:student_6).id]
    members(:f_mentor).update_attribute(:last_suspended_at, day1)
    members(:robert).update_attribute(:last_suspended_at, day2)
    members(:student_1).update_attribute(:last_suspended_at, day3)
    assert_nil members(:student_6).last_suspended_at

    csv_content = Enumerator.new do |stream|
      organization_admin_view.report_to_stream(stream, member_ids, organization_admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal (member_ids.size + 1), csv_array.size
    assert_equal ["Last Suspended On"], csv_array.first
    assert_equal [DateTime.localize(day1, format: :default_dashed)], csv_array[1]
    assert_equal [DateTime.localize(day2, format: :default_dashed)], csv_array[2]
    assert_equal [DateTime.localize(day3, format: :default_dashed)], csv_array[3]
    assert_empty csv_array[4]
  end

  def test_meeting_request_columns_report_to_stream
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    filter_params = { connection_status: { meeting_requests: { mentees: "1", mentors: "1" }, advanced_options: { meeting_requests: { mentors: { request_duration: "3", "1" => "", "2" => "", "3" => "01/01/2015" }, mentees: { request_duration: "4", "1" => "", "2" => "", "3" => "" } } } } }
    admin_view = program.admin_views.create!(title: "Users with Meeting Requests", filter_params: filter_params.to_yaml)
    users = program.users
    admin_view.admin_view_columns.create!(column_key: "meeting_requests_received_v1")
    admin_view.admin_view_columns.create!(column_key: "meeting_requests_sent_v1")
    admin_view.admin_view_columns.create!(column_key: "meeting_requests_sent_and_accepted_v1")
    admin_view.admin_view_columns.create!(column_key: "meeting_requests_received_and_accepted_v1")
    admin_view.admin_view_columns.create!(column_key: "meeting_requests_sent_and_pending_v1")
    admin_view.admin_view_columns.create!(column_key: "meeting_requests_received_and_pending_v1")

    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, users.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal (users.size + 1), csv_array.size
    assert_equal "Meeting requests received,Meeting requests sent,Meeting requests sent & accepted,Meeting requests received & accepted,Meeting requests sent & pending action,Meeting requests received & pending action".split(","), csv_array.first
    assert_equal "NA,NA,NA,NA,NA,NA".split(","), csv_array[1]
    assert_equal "NA,2,0,NA,1,NA".split(","), csv_array[2]
    assert_equal "5,NA,NA,4,NA,1".split(","), csv_array[3]
    assert_equal ["0", "0", "0", "0", "0", "0"], csv_array[5]
  end

  def test_mentoring_request_columns_report_to_stream
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    filter_params = { connection_status: { mentoring_requests: { mentees: "1", mentors: "1" }, advanced_options: { mentoring_requests: { mentors: { request_duration: "3", "1" => "", "2" => "", "3" => "01/01/2015" }, mentees: { request_duration: "3", "1" => "", "2" => "", "3" => "" } } } } }
    admin_view = program.admin_views.create!(title: "Users with Mentoring Requests", filter_params: filter_params.to_yaml)
    users = program.users
    admin_view.admin_view_columns.create!(column_key: "mentoring_requests_sent_v1")
    admin_view.admin_view_columns.create!(column_key: "mentoring_requests_received_v1")
    admin_view.admin_view_columns.create!(column_key: "mentoring_requests_sent_and_pending_v1")
    admin_view.admin_view_columns.create!(column_key: "mentoring_requests_received_and_pending_v1")

    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, users.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal (users.size + 1), csv_array.size
    assert_equal "Mentoring requests sent,Mentoring requests received,Mentoring requests sent & pending action,Mentoring requests received & pending action".split(","), csv_array.first
    assert_equal "NA,NA,NA,NA".split(","), csv_array[1]
    assert_equal "0,NA,0,NA".split(","), csv_array[2]
    assert_equal "NA,15,NA,11".split(","), csv_array[3]
    assert_equal ["0", "0", "0", "0"], csv_array[5]
  end

  def test_users_report_to_stream
    program = programs(:albers)
    admin_view = program.admin_views.first
    filter_params_hash = admin_view.filter_params_hash.merge!(connection_status: { mentoring_requests: { mentees: "1", mentors: "1" },
      advanced_options: { mentoring_requests: { mentors: { request_duration: "3", "1" => "", "2" => "", "3" => "01/01/2015" },
        mentees: { request_duration: "4", "1" => "", "2" => "", "3" => ""} } } } )
    admin_view.update_attributes!(filter_params: filter_params_hash.to_yaml)

    users = program.users.limit(10)
    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, users.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal 11, csv_array.size
    assert_equal "Member ID,First Name,Last Name,Email,Roles,Status,Ongoing Mentoring Connections,Closed Mentoring Connections,Drafted Mentoring Connections,Joined On".split(","), csv_array.first
    assert_equal "Freakin", csv_array.second[1]

    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::AVAILABLE_SLOTS, position: 10)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::PROFILE_SCORE, position: 11)
    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, users.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    dual_role_val = csv_array.select { |val| val[3] == users(:f_mentor_student).email }
    assert_equal 11, csv_array.size
    assert_equal "Member ID,First Name,Last Name,Email,Roles,Status,Ongoing Mentoring Connections,Closed Mentoring Connections,Drafted Mentoring Connections,Joined On,Mentoring Connection slots,Profile Completeness Score".split(","), csv_array.first
    assert_equal "1", csv_array.second[0]
    assert_equal "Freakin", csv_array.second[1]
    assert_equal "Mentor, Student", dual_role_val[0][4]

    admin_view_column = admin_view.admin_view_columns.second
    admin_view_column.update_attributes!(position: 12)
    admin_view_column = admin_view.admin_view_columns.first
    admin_view_column.update_attributes!(position: 1)
    admin_view_column = admin_view.admin_view_columns.where(position: 11).first
    admin_view_column.update_attributes!(position: 0)
    users = program.users.limit(8)
    admin_view.admin_view_columns.reload
    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, users.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal 9, csv_array.size
    assert_equal "Profile Completeness Score,Member ID,Last Name,Email,Roles,Status,Ongoing Mentoring Connections,Closed Mentoring Connections,Drafted Mentoring Connections,Joined On,Mentoring Connection slots,First Name".split(","), csv_array.first
    assert_equal "15", csv_array.second.first
    assert_equal "Freakin", csv_array.second.last

    student = users(:f_student)
    mentor = users(:f_mentor)
    t1 = Time.now
    create_meeting_request(program: program, student: student, mentor: mentor)
    create_mentor_request(program: program, student: student, mentor: mentor)
    t2 = Time.now
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1, position: 13)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_V1, position: 14)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_PENDING, position: 15)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_PENDING, position: 16)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_AND_ACCEPTED, position: 17)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_AND_ACCEPTED, position: 18)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT, position: 19)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED, position: 20)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_SENT_AND_PENDING, position: 21)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_REQUESTS_RECEIVED_AND_PENDING, position: 22)
    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, [mentor.id, student.id], admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal 3, csv_array.size
    assert_equal "Profile Completeness Score,Member ID,Last Name,Email,Roles,Status,Ongoing Mentoring Connections,Closed Mentoring Connections,Drafted Mentoring Connections,Joined On,Mentoring Connection slots,First Name,Meeting requests received,Meeting requests sent,Meeting requests received & pending action,Meeting requests sent & pending action,Meeting requests sent & accepted,Meeting requests received & accepted,Mentoring requests sent,Mentoring requests received,Mentoring requests sent & pending action,Mentoring requests received & pending action".split(","), csv_array.first
    assert_equal ["6", "NA", "2", "NA", "NA", "4", "NA", "16", "NA", "12"], csv_array[1].last(10)
    assert_equal ["NA", "3", "NA", "2", "0", "NA", "1", "NA", "1", "NA"], csv_array[2].last(10)

    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, [mentor.id, student.id], admin_view.admin_view_columns, { "meeting_requests_received_v1" => { start_time: t1, end_time: t2 }, "meeting_requests_sent_v1" => {start_time: t1, end_time: t2}, "meeting_requests_received_and_pending_v1" => { start_time: t1, end_time: t2 }, "meeting_requests_sent_and_pending_v1" => { start_time: t1, end_time: t2 }, "meeting_requests_sent_and_accepted_v1" => { start_time: t1, end_time: t2 }, "meeting_requests_received_and_accepted_v1" => { start_time: t1, end_time: t2 }, "mentoring_requests_sent_v1" => { start_time: t1, end_time: t2 }, "mentoring_requests_received_v1" => { start_time: t1, end_time: t2 }, "mentoring_requests_sent_and_pending_v1" => { start_time: t1, end_time: t2 }, "mentoring_requests_received_and_pending_v1" => { start_time: t1, end_time: t2 } } )
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal ["1", "NA", "1", "NA", "NA", "0", "NA", "1", "NA", "1"], csv_array[1].last(10)
    assert_equal ["NA", "1", "NA", "1", "0", "NA", "1", "NA", "1", "NA"], csv_array[2].last(10)

    # Profile scrore
    users(:f_mentor_student).add_role(RoleConstants::ADMIN_NAME)
    users = users + [users(:f_admin), users(:f_mentor_student)]
    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, users.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    scores = csv_array.map(&:first)
    assert_equal 11, csv_array.size
    assert_equal ["Profile Completeness Score", "15", "15", "59", "15", "18", "15", "15", "15", "21", "18"], scores
    assert_equal_unordered users.map{|user| user.profile_score.sum.to_s}, scores[1..-1]
  end

  def test_members_report_to_stream
    org = programs(:org_primary)
    admin_view = org.admin_views.first
    #admin_view.admin_view_columns.destroy_all
    admin_view.admin_view_columns.create!(column_key: nil, profile_question_id: 8, position: 5)
    members = org.members.limit(10)
    member = members.first
    member.profile_answers.create!(profile_question_id: 8, ref_obj_type: 'Member', ref_obj_id: member.id, answer_text: 'it is me')
    user = member.users.first
    user.update_column(:state, User::Status::SUSPENDED)

    dormant_member = members[1]
    dormant_member.update_column(:state, Member::Status::DORMANT)
    User.where(member_id: dormant_member.id).delete_all

    # education question
    q1 = profile_questions(:profile_questions_6)
    admin_view.admin_view_columns.create!(profile_question: q1, position: 6)
    create_education(user, q1, school_name: "KPI")

    # experience question
    q2 = profile_questions(:profile_questions_7)
    admin_view.admin_view_columns.create!(profile_question: q2, position: 7)
    create_experience(user, q2, job_title: "PM")

    # publication question
    q3 = profile_questions(:publication_q)
    admin_view.admin_view_columns.create!(profile_question: q3, position: 8)
    create_publication(user, q3, title: "Pub")

    # manager question
    q4 = profile_questions(:manager_q)
    admin_view.admin_view_columns.create!(profile_question: q4, position: 9)
    create_manager(user, q4, first_name: "Man1")

    csv_content = Enumerator.new do |stream|
      admin_view.report_to_stream(stream, members.collect(&:id), admin_view.admin_view_columns)
    end
    csv_array = CSV.parse(csv_content.to_a.join)
    assert_equal 11, csv_array.size
    assert_equal ["Member ID", "First Name", "Last Name", "Email", "Status", "Programs", "About Me", "Last Suspended On", "Education-College/School Name", "Education-Degree", "Education-Major", "Education-Graduation Year", "Work-Job Title", "Work-Start year", "Work-End year", "Work-Company/Institution", "Current Publication-Title", "Current Publication-Publication/Publisher", "Current Publication-Publication Date", "Current Publication-Publication URL", "Current Publication-Author(s)", "Current Publication-Description", "Current Manager-First name", "Current Manager-Last name", "Current Manager-Email"], csv_array.first
    assert_equal ["1", "Freakin", "Admin", "ram@example.com", "Active", "Albers Mentor Program (Administrator - Deactivated); Moderated Program (Administrator); NWEN (Administrator); Project Based Engagement (Administrator)", "it is me", nil, "KPI", "BTech", "IT", "2009", "PM", "2000", "2009", "MSFT", "Pub", "Publisher ltd.", "January 03, 2009", "http://public.url", "Author", "Very useful publication", "Man1", "Name", "manager@example.com"], csv_array.second
    assert_equal ["2", "student", "example", "rahim@example.com", "Dormant", "", "", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil], csv_array[2]
  end

  def test_generate_view
    admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    assert_equal_unordered (programs(:albers).all_users - [users(:f_user)]).collect(&:id), admin_view.generate_view("", "", false).to_a

    mentor_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    assert_equal_unordered programs(:albers).mentor_users.collect(&:id), mentor_view.generate_view("", "", false).to_a

    student_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    assert_equal_unordered programs(:albers).student_users.collect(&:id), student_view.generate_view("", "", false).to_a

    admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_ADMINS)
    assert_equal_unordered programs(:albers).admin_users.collect(&:id), admin_view.generate_view("", "", false).to_a
  end

  def test_generate_view_with_pagination
    admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    admin_view.expects(:create_or_update_user_ids_cache).never
    assert_equal_unordered (programs(:albers).all_users - [users(:f_user)]), admin_view.generate_view("last_name", "asc", true, {:page => 1, :per_page => 50}).to_a

    mentor_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    assert_equal_unordered programs(:albers).mentor_users, mentor_view.generate_view("last_name", "asc", true, {:page => 1, :per_page => 50}).to_a

    student_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    assert_equal_unordered programs(:albers).student_users, student_view.generate_view("last_name", "asc", true, {:page => 1, :per_page => 50}).to_a

    total_users_size = (programs(:albers).all_users - [users(:f_user)]).size
    assert_equal 25, admin_view.generate_view("last_name", "asc", true, {:page => 1, :per_page => 25}).to_a.size
    assert_equal total_users_size-25, admin_view.generate_view("last_name", "asc", true, {:page => 2, :per_page => 25}).to_a.size
    assert_false admin_view.generate_view("last_name", "asc", true, {:page => 1, :per_page => 25}).to_a.include?(users(:robert))
    assert admin_view.generate_view("last_name", "asc", true, {:page => 2, :per_page => 25}).to_a.include?(users(:robert))
  end

  def test_generate_view_with_language_column
    org_admin_view = programs(:org_anna_univ).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS)
    get_tmp_language_column(org_admin_view).save

    member_ids = members(:arun_ceg, :f_mentor_ceg, :sarat_mentor_ceg, :anna_univ_admin, :anna_univ_mentor, :cit_admin_mentor, :psg_only_admin, :psg_student1, :psg_student2, :psg_student3, :psg_mentor1, :psg_mentor2, :psg_mentor3, :inactive_user, :psg_remove).map(&:id)
    assert_equal member_ids, org_admin_view.generate_view(AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES, "asc", true, { page: 1, per_page: 100 } ).map(&:id)

    member_ids = members(:psg_only_admin, :psg_student1, :psg_student2, :psg_student3, :psg_mentor1, :psg_mentor2, :psg_mentor3, :inactive_user, :psg_remove, :cit_admin_mentor, :anna_univ_admin, :anna_univ_mentor, :arun_ceg, :f_mentor_ceg, :sarat_mentor_ceg).map(&:id)
    assert_equal member_ids, org_admin_view.generate_view(AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES, "desc", true, { page: 1, per_page: 100 } ).map(&:id)
  end

  def test_count
    view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    assert_equal view.generate_view(AdminView::DEFAULT_SORT_PARAM, AdminView::DEFAULT_SORT_ORDER, false).count, view.count
    view = programs(:org_primary).admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT)
    dynamic_filters = {non_profile_field_filters: [AdminView::MEMBER_WITH_ONGOING_ENGAGEMENTS_FILTER_HSH]}
    assert_equal view.generate_view(nil, nil, false, {count_only: true}, dynamic_filters), view.count(nil, dynamic_filter_params: dynamic_filters)
  end

  def test_members_in_specified_programs
    assert_equal ({"field"=>"program_user_roles", "operator"=>"eq", "value"=>[1, 2, 3]}), AdminView::MEMBERS_IN_SPECIFIED_PROGRAMS.call([1, 2, 3])
  end

  def test_count_with_alert
    program = programs(:albers)
    time_now = Time.now
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::ALL_USERS).first
    section = program.report_sections.first
    metric = create_report_metric({ title: "All Users", description: "All Users description", abstract_view_id: view.id, section_id: section.id })
    alert_params = {target: 10, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::AdminViewFilters::CONNECTION_STATUS_LAST_CLOSED_CONNECTION, operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)
    count1 = metric.count(alert)
    users1 = view.generate_view(nil, nil, false, {}, {}, alert)
    users2 = program.groups.closed.where(closed_at: (time_now-10.days)..time_now).collect(&:members).flatten.uniq.collect(&:id)
    assert_equal_unordered users2.uniq, users1.uniq
    assert_equal count1, users2.uniq.count
  end

  def test_generate_view_with_filtering
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    question = profile_questions(:profile_questions_4)
    file_question = profile_questions(:mentor_file_upload_q)
    f_mentor.save_answer!(question, 'Bz')
    f_admin.save_answer!(file_question, fixture_file_upload(File.join('files', 'test_file.css')))

    prog_admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    prog_admin_view.admin_view_columns.create!(profile_question: question)
    prog_admin_view.admin_view_columns.create!(profile_question: file_question)
    file_question_column = prog_admin_view.admin_view_columns.where(:profile_question_id => file_question.id).first
    question_column = prog_admin_view.admin_view_columns.where(:profile_question_id => question.id).first
    assert_equal [f_mentor.id], prog_admin_view.generate_view("", "", false, {}, :role_names => ['mentor'], :profile_field_filters => [{"field"=>"column#{question_column.id}", "value"=>"bz"}]).to_a
    assert_equal [f_admin.id], prog_admin_view.generate_view("", "", false, {}, :role_names => ['admin'], :profile_field_filters => [{"field"=>"column#{file_question_column.id}", "value"=>"true"}]).to_a
  end

  def test_apply_roles_dynamic_filtering
    f_admin = users(:f_admin)
    admin_view = programs(:albers).admin_views.default.find_by(default_view: AdminView::DefaultType::ALL_ADMINS)
    users = admin_view.generate_view("first_name","asc", true, {:page => 1, :per_page => 25},{:role_names => ['mentor']})
    users.each do |user|
      assert user.roles.each.collect(&:name).include? 'mentor'
    end
  end

  def test_apply_non_profile_filtering_for_net_recommended_count
    f_mentor  = users(:f_mentor)
    prog_admin_view = programs(:albers).admin_views.default.find_by(default_view: AdminView::DefaultType::ALL_USERS)
    recommendation_preference = RecommendationPreference.create(user_id: f_mentor.id, mentor_recommendation_id: mentor_recommendations(:mentor_recommendation_1).id)
    f_mentor.reload
    reindex_documents(updated: f_mentor)
    assert_equal [f_mentor.id], prog_admin_view.send(:apply_non_profile_filtering, [users(:f_admin).id, f_mentor.id, users(:f_student).id, users(:inactive_user).id], [{"field" => AdminViewColumn::Columns::Key::NET_RECOMMENDED_COUNT, "operator" => 'eq', "value" => f_mentor.net_recommended_count}]).to_a
  end

  def test_get_net_recommended_count_hash
    prog_admin_view = programs(:albers).admin_views.default.find_by(default_view: AdminView::DefaultType::ALL_USERS)
    hsh = prog_admin_view.send(:get_net_recommended_count_hash)
    assert_equal 1, hsh[users(:robert).id]
    assert_equal 0, hsh[users(:rahim).id]
  end

  def test_apply_non_profile_filtering
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    inactive_user = users(:inactive_user)

    f_student.update_attributes!(mentoring_mode: User::MentoringMode::ONGOING)
    f_admin.update_attributes!(mentoring_mode: User::MentoringMode::ONE_TIME)
    reindex_documents(updated: [f_student, f_admin])

    prog_admin_view = programs(:albers).admin_views.default.find_by(default_view: AdminView::DefaultType::ALL_USERS)
    org_admin_view = programs(:org_primary).admin_views.default.find_by(default_view: AdminView::DefaultType::ALL_MEMBERS)

    # Profile Score
    assert_equal [f_mentor.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id], [{"field" => AdminViewColumn::Columns::Key::PROFILE_SCORE, "operator" => 'eq', "value" => f_mentor.profile_score.sum}]).to_a
    # State
    assert_equal [inactive_user.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::STATE, "value" => 'suspended'}]).to_a
    # Available slots
    assert_equal [f_mentor.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::AVAILABLE_SLOTS, "operator" => 'eq', "value" => f_mentor.slots_available}]).to_a
    # Connections
    assert_equal [f_mentor.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::GROUPS, "operator" => 'eq', "value" => f_mentor.active_groups.size}]).to_a

    #Mentoring Mode
    assert_equal [f_student.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::MENTORING_MODE, "operator" => 'eq', "value" => User::MentoringMode::ONGOING.to_s}]).to_a

    assert_equal [f_admin.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::MENTORING_MODE, "operator" => 'eq', "value" => User::MentoringMode::ONE_TIME.to_s}]).to_a

    assert_equal_unordered [f_mentor.id, inactive_user.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::MENTORING_MODE, "operator" => 'eq', "value" => User::MentoringMode::ONE_TIME_AND_ONGOING.to_s}]).to_a

    # Closed Connections
    assert_equal_unordered [f_admin.id, f_student.id, f_mentor.id, inactive_user.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::CLOSED_GROUPS, "operator" => 'eq', "value" => f_mentor.closed_groups.size}]).to_a

    # Drafted Connections
    assert_equal_unordered [f_admin.id, f_student.id, f_mentor.id, inactive_user.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::DRAFTED_GROUPS, "operator" => 'eq', "value" => f_student.drafted_groups.size}]).to_a

    # Created at
    assert_equal_unordered [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::CREATED_AT, "value" => DateTime.localize(f_admin.created_at - 1.day, format: :date_range)}, {"field" => AdminViewColumn::Columns::Key::CREATED_AT, "value" => DateTime.localize(f_admin.created_at + 1.day, format: :date_range)}]).to_a
    # Last seen at
    assert_equal [], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::LAST_SEEN_AT, "value" => "7/8/1999"}]).to_a
    # Terms & conditions
    assert_equal_unordered [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::TERMS_AND_CONDITIONS, "value" => DateTime.localize(f_admin.terms_and_conditions_accepted - 1.day, format: :date_range)}, {"field" => AdminViewColumn::Columns::Key::TERMS_AND_CONDITIONS, "value" => DateTime.localize(f_admin.terms_and_conditions_accepted + 1.day, format: :date_range)}]).to_a

    # Both Created at & Terms &Conditions
    assert_equal_unordered [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::CREATED_AT, "value" => DateTime.localize(f_admin.created_at - 1.day, format: :date_range)}, {"field" => AdminViewColumn::Columns::Key::CREATED_AT, "value" => DateTime.localize(f_admin.created_at + 1.day, format: :date_range)}, {"field" => AdminViewColumn::Columns::Key::TERMS_AND_CONDITIONS, "value" => DateTime.localize(f_admin.terms_and_conditions_accepted - 1.day, format: :date_range)}, {"field" => AdminViewColumn::Columns::Key::TERMS_AND_CONDITIONS, "value" => DateTime.localize(f_admin.terms_and_conditions_accepted + 1.day, format: :date_range)}]).to_a

    # Programs at organization level
    assert_equal_unordered [inactive_user.member.id], org_admin_view.send(:apply_non_profile_filtering, [f_admin.member.id, f_mentor.member.id, f_student.member.id, inactive_user.member.id], [{"field" => AdminViewColumn::Columns::Key::PROGRAM_USER_ROLES, "value" => "#{inactive_user.program.id}"}]).to_a

    assert_equal_unordered [f_mentor.member.id], org_admin_view.send(:apply_non_profile_filtering, [f_admin.member.id, f_mentor.member.id, f_student.member.id, inactive_user.member.id], [{"field" => AdminViewColumn::Columns::Key::ORG_LEVEL_ONGOING_ENGAGEMENTS, "operator" => 'eq', "value" => f_mentor.member.groups.active.size}]).to_a

    # Last deactivated at
    f_student.suspend_from_program!(f_admin, "A reason")
    reindex_documents(updated: f_student)
    assert_equal [f_student.id], prog_admin_view.send(:apply_non_profile_filtering, [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], [{"field" => AdminViewColumn::Columns::Key::LAST_DEACTIVATED_AT, "value" => DateTime.localize(1.day.ago, format: :date_range)}, {"field" => AdminViewColumn::Columns::Key::LAST_DEACTIVATED_AT, "value" => DateTime.localize(1.day.from_now, format: :date_range)}]).to_a

    # return all member ids if no filter is applicable
    Member.expects(:get_filtered_ids).never
    assert_equal [f_admin.member.id, f_mentor.member.id, f_student.member.id, inactive_user.member.id], org_admin_view.send(:apply_non_profile_filtering, [f_admin.member.id, f_mentor.member.id, f_student.member.id, inactive_user.member.id], [{"field"=>"last_name", "operator"=>"eq", "value"=>"invalid"}])
  end

  def test_generate_org_view_in_not_in_operator
    org = programs(:org_primary)
    ram = members(:ram)
    rahim = members(:rahim)
    robert = members(:robert)
    question1 = profile_questions(:student_single_choice_q)
    question2 = profile_questions(:student_multi_choice_q)
    qc_text_hash = {}
    question1.question_choices.each do |qc|
      qc_text_hash[qc.text] = qc.id
    end
    question2.question_choices.each do |qc|
      qc_text_hash[qc.text] = qc.id
    end
    ProfileAnswer.create!(profile_question_id: question1.id, answer_value: {answer_text: "opt_1", question: question1}, ref_obj: ram)
    ProfileAnswer.create!(profile_question_id: question1.id, answer_value: {answer_text: "opt_2", question: question1}, ref_obj: rahim)
    ProfileAnswer.create!(profile_question_id: question1.id, answer_value: {answer_text: "opt_3", question: question1}, ref_obj: robert)
    ProfileAnswer.create!(profile_question_id: question2.id, answer_value: {answer_text: "Stand", question: question2}, ref_obj: robert)
    admin_view = AdminView.create!(program: org, title: "New View", filter_params: AdminView.convert_to_yaml({
      member_status: {state: {"0" => Member::Status::ACTIVE}},
      profile: {"questions"=> {"questions_2"=>{"question"=>"#{question1.id}", "operator"=>"7", "choice"=>[qc_text_hash["opt_1"], qc_text_hash["opt_2"]].join(",")}, "questions_3"=>{"question"=>"#{question2.id}", "operator"=>"8", "choice"=>qc_text_hash["Stand"].to_s } } },
      program_role_state: {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))
    view = admin_view.generate_organization_view(nil, nil, nil, {}, {})
    assert_equal_unordered [ram.id, rahim.id], view.to_a

    # With Matches
    admin_view = AdminView.create!(program: org, title: "New View2", filter_params: AdminView.convert_to_yaml({
      member_status: {state: {"0" => Member::Status::ACTIVE}},
      profile: {"questions"=> {"questions_2"=>{"question"=>"#{question1.id}", "operator"=>"10", "value"=>"opt_1,opt_2"}, "questions_3"=>{"question"=>"#{question2.id}", "operator"=>"8", "choice"=>qc_text_hash["Stand"].to_s } } },
      program_role_state: {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))
    view = admin_view.generate_organization_view(nil, nil, nil, {}, {})
    assert_equal_unordered [ram.id, rahim.id], view.to_a
  end

  def test_generate_org_view_with_member_user_state_check_happens
    org = programs(:org_primary)
    rahim = members(:rahim)
    ram = members(:ram)
    ram.users.update_all(state: "suspended")
    reindex_documents(updated: ram.users)

    admin_view = AdminView.create!(:program => programs(:org_anna_univ), :title => "New View", :filter_params => AdminView.convert_to_yaml({
      :member_status => {:state => {"#{Member::Status::SUSPENDED}" => Member::Status::SUSPENDED}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
      }))
    view = admin_view.generate_organization_view(nil, nil, nil, {}, {})
    assert_equal [members(:inactive_user).id], view.to_a
    admin_view = AdminView.create!(:program => org, :title => "New View", :filter_params => AdminView.convert_to_yaml({
      :member_status => {:state => {"#{Member::Status::ACTIVE}" => Member::Status::ACTIVE}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::EXCLUDE, :filter_conditions => {:parent_filter_2 => {:child_filter_1 => {AdminView::ProgramRoleStateFilterObjectKey::STATE => [User::Status::ACTIVE]}}}}
      }))
    view = admin_view.generate_organization_view(nil, nil, nil, {}, {})
    assert_equal_unordered [ram.id, members(:pending_user).id], view.to_a
    admin_view.update_attributes!(filter_params: AdminView.convert_to_yaml({
      :member_status => {AdminView::ProgramRoleStateFilterObjectKey::STATE => {"#{Member::Status::ACTIVE}" => Member::Status::ACTIVE}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, :filter_conditions => {:parent_filter_2 => {:child_filter_1 => {AdminView::ProgramRoleStateFilterObjectKey::STATE => [User::Status::ACTIVE]}}}}
      }))
    view = admin_view.generate_organization_view(nil, nil, nil, {}, {})
    assert view.to_a.include?(members(:f_mentor).id)
    admin_view = AdminView.create!(:program => programs(:org_no_subdomain), :title => "New View", :filter_params => AdminView.convert_to_yaml({
      :member_status => {:state => {"#{Member::Status::DORMANT}" => Member::Status::DORMANT}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::EXCLUDE, :filter_conditions => {:parent_filter_2 => {:child_filter_1 => {AdminView::ProgramRoleStateFilterObjectKey::STATE => [User::Status::ACTIVE]}}}}
      }))
    view = admin_view.generate_organization_view(nil, nil, nil, {}, {})
    assert_equal [members(:dormant_member).id], view.to_a
  end

  def test_generate_org_view_in_not_in_operator_text_field_question
    org = programs(:org_primary)
    ram = members(:ram)
    rahim = members(:rahim)
    robert = members(:robert)
    question1 = profile_questions(:string_q)
    question2 = question1.dup
    question2.question_text = "text based question"
    question2.save!
    ProfileAnswer.create!(profile_question_id: question1.id, answer_text: "ans1", ref_obj: ram)
    ProfileAnswer.create!(profile_question_id: question1.id, answer_text: "ans2", ref_obj: rahim)
    ProfileAnswer.create!(profile_question_id: question1.id, answer_text: "ans3", ref_obj: robert)
    ProfileAnswer.create!(profile_question_id: question2.id, answer_text: "ans4", ref_obj: robert)
    admin_view = AdminView.create!(:program => org, :title => "New View", :filter_params => AdminView.convert_to_yaml({
      profile: {"questions"=> {"questions_1"=>{"question"=>"#{question1.id}", "operator"=>AdminViewsHelper::QuestionType::IN.to_s, "value"=>"ans1,ans2,ans3"}, "questions_2"=>{"question"=>"#{question2.id}", "operator"=>AdminViewsHelper::QuestionType::NOT_IN.to_s, "value"=>"ans4"}}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))
    view = admin_view.generate_organization_view(nil, nil, nil, {}, {})
    assert_equal_unordered [ram.id, rahim.id], view.to_a
  end

  def test_generate_organization_view
    admin_view = AdminView.create!(:program => programs(:org_primary), :title => "New View", :filter_params => AdminView.convert_to_yaml({
      :member_status => {:state => {"0" => Member::Status::ACTIVE}},
      :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))

    assert_equal_unordered [members(:f_mentor).id, members(:robert).id, members(:no_mreq_mentor).id, members(:no_mreq_student).id], admin_view.generate_organization_view("", "", false, {}, {}).to_a

    albers_mentor_id = programs(:albers).find_role(RoleConstants::MENTOR_NAME).id.to_s
    nwen_student_id = programs(:nwen).find_role(RoleConstants::STUDENT_NAME).id.to_s

    albers_program_id = programs(:albers).id.to_s
    nwen_program_id = programs(:nwen).id.to_s
    moderated_program_id = programs(:moderated_program).id.to_s

    admin_view.filter_params = AdminView.convert_to_yaml({
      :member_status => {:state => {"0" => Member::Status::ACTIVE}},
      :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, :filter_conditions => {:parent_filter_1 => {:child_filter_1 => {AdminView::ProgramRoleStateFilterObjectKey::PROGRAM => [albers_program_id], AdminView::ProgramRoleStateFilterObjectKey::ROLE => ["mentor"]}}}}
    })

    admin_view.save!
    assert_equal_unordered [members(:f_mentor).id, members(:robert).id], admin_view.generate_organization_view("", "", false, {}, {}).to_a

     admin_view.filter_params = AdminView.convert_to_yaml({
      :member_status => {:state => {"0" => Member::Status::ACTIVE}, status_filters: {
      status_filter_0: {AdminView::ConnectionStatusFilterObjectKey::CATEGORY => AdminView::ConnectionStatusCategoryKey::ADVANCED_FILTERS, AdminView::ConnectionStatusFilterObjectKey::TYPE => AdminView::ConnectionStatusTypeKey::ONGOING, AdminView::ConnectionStatusFilterObjectKey::OPERATOR => AdminView::ConnectionStatusOperatorKey::LESS_THAN, AdminView::ConnectionStatusFilterObjectKey::COUNT_VALUE => 100}}},
      :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, :filter_conditions => {:parent_filter_1 => {:child_filter_1 => {AdminView::ProgramRoleStateFilterObjectKey::PROGRAM => [albers_program_id], AdminView::ProgramRoleStateFilterObjectKey::ROLE => ["mentor"]}}}}
    })
     admin_view.save!

    assert_equal_unordered [members(:f_mentor).id, members(:robert).id], admin_view.generate_organization_view("", "", false, {}, {}).to_a

    admin_view.filter_params = AdminView.convert_to_yaml({
      :member_status => {:state => {"0" => Member::Status::ACTIVE}},
      :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, :filter_conditions => {:parent_filter_1 => {:child_filter_1 => {AdminView::ProgramRoleStateFilterObjectKey::PROGRAM => [nwen_program_id], AdminView::ProgramRoleStateFilterObjectKey::ROLE => ["student"]}}}}
    })
    admin_view.save!

    assert_equal_unordered [members(:f_mentor).id], admin_view.generate_organization_view("", "", false, {}, {}).to_a

     admin_view.filter_params = AdminView.convert_to_yaml({
      :member_status => {:state => {"0" => Member::Status::ACTIVE}},
      :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, :filter_conditions => {:parent_filter_1 => {:child_filter_1 => {AdminView::ProgramRoleStateFilterObjectKey::PROGRAM => [nwen_program_id], AdminView::ProgramRoleStateFilterObjectKey::ROLE => ["student"]}, :child_filter_2 => {AdminView::ProgramRoleStateFilterObjectKey::PROGRAM => [albers_program_id], AdminView::ProgramRoleStateFilterObjectKey::ROLE => ["mentor"]}}}}
    })
    admin_view.save!

    assert_equal_unordered [members(:f_mentor).id, members(:robert).id], admin_view.generate_organization_view("", "", false, {}, {}).to_a

    admin_view.filter_params = AdminView.convert_to_yaml({
      :member_status => {:state => {"0" => Member::Status::ACTIVE}},
      :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE, :filter_conditions => {:parent_filter_1 => {:child_filter_1 => {AdminView::ProgramRoleStateFilterObjectKey::PROGRAM => [nwen_program_id], AdminView::ProgramRoleStateFilterObjectKey::ROLE => ["student"]}, :child_filter_2 => {AdminView::ProgramRoleStateFilterObjectKey::PROGRAM => [albers_program_id], AdminView::ProgramRoleStateFilterObjectKey::ROLE => ["mentor"]}}, :parent_filter_2 => {:child_filter_3 => {AdminView::ProgramRoleStateFilterObjectKey::PROGRAM => [moderated_program_id], AdminView::ProgramRoleStateFilterObjectKey::ROLE => ["mentor"]}}}}
    })  
    admin_view.save!

    assert_equal_unordered [members(:f_mentor).id], admin_view.generate_organization_view("", "", false, {}, {}).to_a
  end

  def test_generate_organization_view_only_profile_filter
    Member.expects(:esearch).never
    Member.expects(:chronus_elasticsearch).never
    Member.expects(:ecount).never
    admin_view = AdminView.create!(:program => programs(:org_primary), :title => "New View", :filter_params => AdminView.convert_to_yaml({
      :member_status => {:state => {"0" => Member::Status::ACTIVE}},
      :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
      :program_role_state => {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))
    assert_equal_unordered [members(:f_mentor).id], admin_view.generate_organization_view("", "", false, {member_ids: [members(:f_mentor).id], only_profile_filters: true}, {}).to_a
  end

  def test_generate_view_using_member_id
    program = programs(:albers)
    organization = program.organization

    all_users_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    all_members_view = organization.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS)

    all_users = all_users_view.generate_view(AdminViewColumn::Columns::Key::FIRST_NAME, "asc", true).to_a
    all_members = all_members_view.generate_view(AdminViewColumn::Columns::Key::FIRST_NAME, "asc", true).to_a
    assert_equal (program.all_user_ids - [users(:f_user).id]).size, all_users.size
    assert_equal organization.members.size, all_members.size
    assert_not_equal all_users, program.all_users.where.not(id: users(:f_user).id).order(:member_id).pluck(:id)
    assert_not_equal all_members, organization.members.order(:id).pluck(:id)

    # Filtering using member_id
    assert_equal [users(:f_admin).id], all_users_view.generate_view("", "", false, {}, { member_id: members(:f_admin).id }).to_a
    assert_equal [members(:f_admin).id], all_members_view.generate_view("", "", false, {}, { member_id: members(:f_admin).id }).to_a

    # Sorting using member_id
    all_users_sorted = all_users_view.generate_view(AdminViewColumn::Columns::Key::MEMBER_ID, "asc", true).to_a
    all_members_sorted = all_members_view.generate_view(AdminViewColumn::Columns::Key::MEMBER_ID, "desc", true).to_a
    assert_equal (program.all_user_ids - [users(:f_user).id]).size, all_users_sorted.size
    assert_equal organization.members.size, all_members_sorted.size
    assert_equal all_users_sorted, program.all_users.where.not(id: users(:f_user).id).order(:member_id).pluck(:id)
    assert_equal all_members_sorted, organization.members.order("id desc").pluck(:id)
  end

  def test_fetch_all_users_or_members
    mentor_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    assert_equal_unordered programs(:albers).mentor_users, mentor_view.fetch_all_users_or_members
  end

  def test_location_scope_valid_values
    assert_equal [AdminView::LocationScope::CITY, AdminView::LocationScope::STATE, AdminView::LocationScope::COUNTRY], AdminView::LocationScope.valid_values
  end

  def test_get_profile_applied_filters_for_locations
    view = AdminView.first
    [AdminViewsHelper::QuestionType::WITH_VALUE.to_s, AdminViewsHelper::QuestionType::IN.to_s, AdminViewsHelper::QuestionType::NOT_IN.to_s].each do |operator|
      assert_equal [{:question_text=>"Location", :operator_text=>view.send(:get_profile_filter_options).invert[operator.to_i], :value=>"India, Ukraine"}], view.send(:get_profile_applied_filters, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
      assert_equal [{:question_text=>"Location", :operator_text=>view.send(:get_profile_filter_options).invert[operator.to_i], :value=>"TN (India), Vitali (Ukraine)"}], view.send(:get_profile_applied_filters, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "TN, India|Vitali, Ukraine"}})
      assert_equal [{:question_text=>"Location", :operator_text=>view.send(:get_profile_filter_options).invert[operator.to_i], :value=>"Chennai (TN, India), Kiev (Vitali, Ukraine)"}], view.send(:get_profile_applied_filters, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, TN, India|Kiev, Vitali, Ukraine"}})
    end
  end

  def test_get_profile_applied_filters
    view = programs(:org_primary).admin_views.first
    value = "12345"
    # Case 1: When the filter_params_hash contains an existing profile_question's id
    question = profile_questions(:profile_questions_4)
    profile_param = { questions_1: { question: question.id, operator: AdminViewsHelper::QuestionType::WITH_VALUE.to_s, value: value } }
    profile_fields_array = view.send(:get_profile_applied_filters, profile_param)
    assert_equal [{ question_text: question.question_text, operator_text: "Contains", value: value }], profile_fields_array

    # Case 2: When the filter_params_hash contains a deleted profile_question's id
    question.destroy
    profile_fields_array = view.send(:get_profile_applied_filters, profile_param)
    assert_empty profile_fields_array

    question = profile_questions(:single_choice_q)
    profile_param = { questions_1: { question: question.id, operator: AdminViewsHelper::QuestionType::IN.to_s, choice: question_choices(:single_choice_q_1).id.to_s } }
    profile_fields_array = view.send(:get_profile_applied_filters, profile_param)
    assert_equal [{ question_text: question.question_text, operator_text: "Contains Any Of", value: question_choices(:single_choice_q_1).text }], profile_fields_array

    profile_param = { questions_1: { question: question.id, operator: AdminViewsHelper::QuestionType::MATCHES.to_s, value: "Stand" } }
    profile_fields_array = view.send(:get_profile_applied_filters, profile_param)
    assert_equal [{ question_text: question.question_text, operator_text: "Matches", value: "Stand"}], profile_fields_array

  end

  def test_refine_profile_params
    org = programs(:org_primary)
    member = members(:f_admin)
    question = profile_questions(:profile_questions_4)
    admin_view = admin_views(:admin_views_2) # All members view
    member.profile_answers.create!(profile_question_id: question.id, answer_text: "12345")
    # Case 1: When the filter_params_hash contains an existing profile_question's id
    assert_equal [member.id], admin_view.send(:refine_profile_params, org.member_ids, { question_1: { question: question.id, operator: AdminViewsHelper::QuestionType::WITH_VALUE.to_s } })

    # Case 2: When the filter_params_hash contains a deleted profile_question's id
    question.destroy
    assert_equal org.member_ids, admin_view.send(:refine_profile_params, org.member_ids, { question_1: { question: question.id, operator: AdminViewsHelper::QuestionType::WITH_VALUE.to_s } })

    question = profile_questions(:single_choice_q)
    member = members(:f_mentor)
    assert_equal [member.id], admin_view.send(:refine_profile_params, org.member_ids, { question_1: { question: question.id, operator: AdminViewsHelper::QuestionType::WITH_VALUE.to_s, choice: question_choices(:single_choice_q_1).id.to_s } })

    # for date type profile question
    question = profile_questions(:date_question)
    admin_view.expects(:get_date_range_string_for_variable_days).with("01/01/2012 - 02/02/2013 - custom", nil, '').returns("01/01/2012 - 02/02/2013")
    UserProfileFilterService.expects(:filter_based_on_question_type!)
    admin_view.send(:refine_profile_params, org.member_ids, { question_1: { question: question.id, "date_value" => "01/01/2012 - 02/02/2013 - custom",  operator: "11" } })
  end

  def test_refine_profile_params_for_locations
    # sadly can't refactor this test easily, will re-visit if I have time
    organization = programs(:org_primary)
    program = programs(:albers)
    organization_admin_view = AdminView.create!(program: organization, :title => "Org Location View", :filter_params => AdminView.convert_to_yaml({}))
    program_admin_view = AdminView.create!(program: program, :title => "Program Location View", :filter_params => AdminView.convert_to_yaml({}))

    member_ids = organization.members.pluck(:id)
    # org level, country level
    # for contains filter
    admin_view = organization_admin_view
    Member.where(id: [8, 69]).map{|m| m.profile_answers.where(profile_question_id: 3)}.flatten.map{|pa| pa.update_attributes({location_id: Location.where(country: "Nice Country").first.id})}
    selected_member_ids = [3, 70]
    operator = AdminViewsHelper::QuestionType::WITH_VALUE.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})
    # for in filter
    operator = AdminViewsHelper::QuestionType::IN.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})
    # for not in filter
    operator = AdminViewsHelper::QuestionType::NOT_IN.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})
    selected_member_ids = [3, 8, 69, 70]
    # for filled filter
    operator = AdminViewsHelper::QuestionType::ANSWERED.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})
    # for not filled filter
    operator = AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})

    # org level, state level
    # for contains filter
    admin_view = organization_admin_view
    Member.where(id: [8, 69]).map{|m| m.profile_answers.where(profile_question_id: 3)}.flatten.map{|pa| pa.update_attributes({location_id: Location.where(state: "Delhi").first.id})}
    selected_member_ids = [3, 70]
    operator = AdminViewsHelper::QuestionType::WITH_VALUE.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})
    # for in filter
    operator = AdminViewsHelper::QuestionType::IN.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})
    # for not in filter
    operator = AdminViewsHelper::QuestionType::NOT_IN.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})
    selected_member_ids = [3, 8, 69, 70]
    # for filled filter
    operator = AdminViewsHelper::QuestionType::ANSWERED.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})
    # for not filled filter
    operator = AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})

    # org level, city level
    # for contains filter
    admin_view = organization_admin_view
    location = Location.create(city: "Salem", state: "Tamil Nadu", country: "India", full_address: "Salem 1, Tamil Nadu, Chennai")
    Member.where(id: [8, 69]).map{|m| m.profile_answers.where(profile_question_id: 3)}.flatten.map{|pa| pa.update_attributes({location_id: location.id})}
    selected_member_ids = [3, 70]
    operator = AdminViewsHelper::QuestionType::WITH_VALUE.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})
    # for in filter
    operator = AdminViewsHelper::QuestionType::IN.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})
    # for not in filter
    operator = AdminViewsHelper::QuestionType::NOT_IN.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})
    selected_member_ids = [3, 8, 69, 70]
    # for filled filter
    operator = AdminViewsHelper::QuestionType::ANSWERED.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})
    # for not filled filter
    operator = AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})

    member_ids = program.users.pluck(:member_id)

    # prog level, country level
    # for contains filter
    admin_view = program_admin_view
    Member.where(id: [8]).map{|m| m.profile_answers.where(profile_question_id: 3)}.flatten.map{|pa| pa.update_attributes({location_id: Location.where(country: "Nice Country").first.id})}
    selected_member_ids = [3]
    operator = AdminViewsHelper::QuestionType::WITH_VALUE.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})
    # for in filter
    operator = AdminViewsHelper::QuestionType::IN.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})
    # for not in filter
    operator = AdminViewsHelper::QuestionType::NOT_IN.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})
    selected_member_ids = [3, 8]
    # for filled filter
    operator = AdminViewsHelper::QuestionType::ANSWERED.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})
    # for not filled filter
    operator = AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India|Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "India"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::COUNTRY, value: "Ukraine"}})

    # prog level, state level
    # for contains filter
    admin_view = program_admin_view
    Member.where(id: [8]).map{|m| m.profile_answers.where(profile_question_id: 3)}.flatten.map{|pa| pa.update_attributes({location_id: Location.where(state: "Delhi").first.id})}
    selected_member_ids = [3]
    operator = AdminViewsHelper::QuestionType::WITH_VALUE.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})
    # for in filter
    operator = AdminViewsHelper::QuestionType::IN.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})
    # for not in filter
    operator = AdminViewsHelper::QuestionType::NOT_IN.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})
    selected_member_ids = [3, 8]
    # for filled filter
    operator = AdminViewsHelper::QuestionType::ANSWERED.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})
    # for not filled filter
    operator = AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India|Kiev, Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Tamil Nadu, India"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::STATE, value: "Kiev, Ukraine"}})

    # prog level, city level
    # for contains filter
    admin_view = program_admin_view
    location = Location.create(city: "Salem", state: "Tamil Nadu", country: "India", full_address: "Salem, Tamil Nadu, Chennai")
    Member.where(id: [8]).map{|m| m.profile_answers.where(profile_question_id: 3)}.flatten.map{|pa| pa.update_attributes({location_id: location.id})}
    selected_member_ids = [3]
    operator = AdminViewsHelper::QuestionType::WITH_VALUE.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})
    # for in filter
    operator = AdminViewsHelper::QuestionType::IN.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal [], admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})
    # for not in filter
    operator = AdminViewsHelper::QuestionType::NOT_IN.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})
    selected_member_ids = [3, 8]
    # for filled filter
    operator = AdminViewsHelper::QuestionType::ANSWERED.to_s
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})
    # for not filled filter
    operator = AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India|Kiev, Kiev, Ukraine"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Chennai, Tamil Nadu, India"}})
    assert_equal member_ids - selected_member_ids, admin_view.send(:refine_profile_params, member_ids, {question_1: {question: "3", operator: operator, scope: AdminView::LocationScope::CITY, value: "Kiev, Kiev, Ukraine"}})
  end

  def test_get_org_applied_filters
    all_members_hash = {"Status"=>"Any Status"}
    license_count_hash = {"Show"=>"Members who are active in at least one track"}
    assert_equal all_members_hash, programs(:org_primary).admin_views.find_by(title: "All Members").get_org_applied_filters({:program_customized_term => "track"})
    assert_equal license_count_hash, programs(:org_primary).admin_views.find_by(title: "Users Counting Against License").get_org_applied_filters({:program_customized_term => "track"})
  end

  def test_get_applied_filters
    programs(:albers).enable_feature(FeatureName::CALENDAR, true)
    mentor_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    filters = mentor_view.get_applied_filters
    assert_equal ["Roles"], filters.keys
    assert_equal ["#{RoleConstants::MENTOR_NAME}".capitalize], filters.values

    new_view = AdminView.create!(:program => programs(:albers), :title => "New View", :filter_params => AdminView.convert_to_yaml({
            :roles_and_status => {role_filter_1: {type: :include, :roles => RoleConstants::DEFAULT_ROLE_NAMES}},
            :connection_status => {:status => UsersIndexFilters::Values::CONNECTED, :availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}, :mentoring_requests => {:mentees => "1", :mentors => "1"}, :meeting_requests => {:mentees => "1", :mentors => "1"}, :meetingconnection_status => "1", :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}, :mentees => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}},
            :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
            :others => {:tags => "1,2,3"},
            :timeline => {:timeline_questions => {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :type =>"2" ,:value => "9/20/2027"}}}
            }))
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "Mentoring Connection Status", "Mentor Availability", "Meeting Requests", "Mentoring Requests", "Users who are", "Tags", "Profile", "Timeline"], filters.keys
    assert_equal ["Administrator, Mentor and Student", "Currently connected", "Have connection slots less than 2", ["Sent meeting requests ", "Received meeting requests After 01/01/2015"], ["Sent mentoring requests Before 01/01/2015", "Received mentoring requests In last 10 days"], "Not connected (Not part of any meeting request which is accepted) In last 10 days", "1,2,3", [{:question_text=>"Location", :operator_text=>"Filled", :value=>""}], ["Last login date: Before 9/20/2027"]], filters.values

    new_view = AdminView.create!(:program => programs(:albers), :title => "New View 1", :filter_params => AdminView.convert_to_yaml({
            :roles_and_status => {role_filter_1: {type: :include, :roles => [RoleConstants::MENTOR_NAME]}},
            :connection_status => {:status => UsersIndexFilters::Values::CONNECTED, :availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}, :mentoring_requests => {:mentees => "1", :mentors => "1"}, :meeting_requests => {:mentees => "1", :mentors => "1"}, :meetingconnection_status => "1", :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}, :mentees => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}},
            :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
            :others => {:tags => "1,2,3"},
            :timeline => {:timeline_questions => {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :type =>"2" ,:value => "9/20/2027"}}}
            }))
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "Mentoring Connection Status", "Mentor Availability", "Meeting Requests", "Mentoring Requests", "Users who are", "Tags", "Profile", "Timeline"], filters.keys
    assert_equal ["Mentor", "Currently connected", "Have connection slots less than 2", ["Received meeting requests After 01/01/2015"], ["Received mentoring requests In last 10 days"], "Not connected (Not part of any meeting request which is accepted) In last 10 days", "1,2,3", [{:question_text=>"Location", :operator_text=>"Filled", :value=>""}], ["Last login date: Before 9/20/2027"]], filters.values

    new_view = AdminView.create!(:program => programs(:albers), :title => "New View 2", :filter_params => AdminView.convert_to_yaml({
            :roles_and_status => {role_filter_1: {type: :include, :roles => [RoleConstants::STUDENT_NAME]}},
            :connection_status => {:status => UsersIndexFilters::Values::CONNECTED, :availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}, :mentoring_requests => {:mentees => "1", :mentors => "1"}, :meeting_requests => {:mentees => "1", :mentors => "1"}, :meetingconnection_status => "1", :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}, :mentees => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}},
            :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
            :others => {:tags => "1,2,3"},
            :timeline => {:timeline_questions => {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :type =>"2" ,:value => "9/20/2027"}}}
            }))
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "Mentoring Connection Status", "Meeting Requests", "Mentoring Requests", "Users who are", "Tags", "Profile", "Timeline"], filters.keys
    assert_equal ["Student", "Currently connected", ["Sent meeting requests "], ["Sent mentoring requests Before 01/01/2015"], "Not connected (Not part of any meeting request which is accepted) In last 10 days", "1,2,3", [{:question_text=>"Location", :operator_text=>"Filled", :value=>""}], ["Last login date: Before 9/20/2027"]], filters.values

    new_view = AdminView.create!(:program => programs(:albers), :title => "New View 3", :filter_params => AdminView.convert_to_yaml({
            :roles_and_status => {role_filter_1: {type: :include, :roles => [RoleConstants::ADMIN_NAME]}},
            :connection_status => {:status => UsersIndexFilters::Values::CONNECTED, :availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}, :mentoring_requests => {:mentees => "1", :mentors => "1"}, :meeting_requests => {:mentees => "1", :mentors => "1"}, :meetingconnection_status => "1", :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}, :mentees => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}}}},
            :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
            :others => {:tags => "1,2,3"},
            :timeline => {:timeline_questions => {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :type =>"2" ,:value => "9/20/2027"}}}
            }))
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "Tags", "Profile", "Timeline"], filters.keys
    assert_equal ["Administrator", "1,2,3", [{:question_text=>"Location", :operator_text=>"Filled", :value=>""}], ["Last login date: Before 9/20/2027"]], filters.values

    new_view = AdminView.create!(:program => programs(:albers), :title => "Sample View", :filter_params => AdminView.convert_to_yaml({
        :roles_and_status => {role_filter_1: {type: :include, :roles => RoleConstants::DEFAULT_ROLE_NAMES}, :signup_state => {:accepted_not_signed_up_users => "accepted_not_signed_up_users", :added_not_signed_up_users => "added_not_signed_up_users", :signed_up_users => "signed_up_users"}},
        :connection_status => {:status => UsersIndexFilters::Values::CONNECTED, :availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}, :mentoring_requests => {:mentees => "2", :mentors => "2"}, :meeting_requests => {:mentees => "2", :mentors => "2"}, :meetingconnection_status => "2", :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}}, :meeting_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}}}},
        :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
        :others => {:tags => ""},
        :timeline => {:timeline_questions => {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :type =>"2" ,:value => "9/20/2027"}}}
    }))
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "User Signup Status", "Mentoring Connection Status", "Mentor Availability", "Meeting Requests", "Mentoring Requests", "Users who are", "Profile", "Timeline"], filters.keys
    assert_equal ["Administrator, Mentor and Student", ["Users who have not signed up after being added", "Users who have not signed up after being accepted", "Signed up users"], "Currently connected", "Have connection slots less than 2", ["Sent meeting requests that are pending action After 01/01/2015", "Received meeting requests that are pending action In last 10 days"], ["Sent mentoring requests that are pending action After 01/01/2015", "Received mentoring requests that are pending action Before 01/01/2015"], "Connected (Part of at least one meeting request which is accepted) Before 01/01/2015", [{:question_text=>"Location", :operator_text=>"Filled", :value=>""}], ["Last login date: Before 9/20/2027"]], filters.values

    new_view = AdminView.create!(:program => programs(:albers), :title => "test View", :filter_params => AdminView.convert_to_yaml({
        :roles_and_status => {role_filter_1: {type: :include, :roles => RoleConstants::DEFAULT_ROLE_NAMES}, :signup_state => {:accepted_not_signed_up_users => "accepted_not_signed_up_users", :added_not_signed_up_users => "added_not_signed_up_users"}},
        :connection_status => {:status => UsersIndexFilters::Values::CONNECTED, :availability => {:operator => "", :value => "2"}, :mentoring_requests => {:mentees => "3", :mentors => "3"}, :meeting_requests => {:mentees => "3", :mentors => "3"}, :meetingconnection_status => "1", :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}}, :meeting_requests => {:mentors => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}, :mentees => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}}}},
        :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}} , :score=>{:operator=>"", :value=>"21"}} ,
        :others => {:tags => ""},
        :timeline => {:timeline_questions => {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :type => "", :value => "9/20/2027"}}}

    }))
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "User Signup Status", "Mentoring Connection Status", "Meeting Requests", "Mentoring Requests", "Users who are", "Profile"], filters.keys
    assert_equal ["Administrator, Mentor and Student", ["Users who have not signed up after being added", "Users who have not signed up after being accepted"], "Currently connected", ["Not sent any meeting requests ", "Not received any meeting requests After 01/01/2015"], ["Not sent any mentoring requests After 01/01/2015", "Not received any mentoring requests "], "Not connected (Not part of any meeting request which is accepted) After 01/01/2015", [{:question_text=>"Location", :operator_text=>"Filled", :value=>""}]], filters.values

    new_view = AdminView.create!(:program => programs(:albers), :title => "Sample Closed View", :filter_params => AdminView.convert_to_yaml({
        :roles_and_status => {role_filter_1: {type: :include, :roles => RoleConstants::DEFAULT_ROLE_NAMES}, :signup_state => {:accepted_not_signed_up_users => "accepted_not_signed_up_users", :added_not_signed_up_users => "added_not_signed_up_users", :signed_up_users => "signed_up_users"}},
        :connection_status => {:status => UsersIndexFilters::Values::CONNECTED, :availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}, :mentoring_requests => {:mentees => "2", :mentors => "5"}, :meeting_requests => {:mentees => "2", :mentors => "5"}, :meetingconnection_status => "2", mentor_recommendations: {mentees: "2"}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}}, :meeting_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}},  :mentor_recommendations => {:mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}}}},
        :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
        :others => {:tags => ""},
        :timeline => {:timeline_questions => {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :type =>"2" ,:value => "9/20/2027"}}}
    }))
    new_view.stubs(:can_show_mentor_recommendation_filter?).returns(true)
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "User Signup Status", "Mentoring Connection Status", "Mentor Availability", "Meeting Requests", "Mentoring Requests", "Users who are", "Mentor Recommendations", "Profile", "Timeline"], filters.keys
    assert_equal ["Administrator, Mentor and Student", ["Users who have not signed up after being added", "Users who have not signed up after being accepted", "Signed up users"], "Currently connected", "Have connection slots less than 2", ["Sent meeting requests that are pending action After 01/01/2015", "Received meeting requests and closed at least one request In last 10 days"], ["Sent mentoring requests that are pending action After 01/01/2015", "Received mentoring requests and closed at least one request Before 01/01/2015"], "Connected (Part of at least one meeting request which is accepted) Before 01/01/2015", "Not received mentor recommendations After 01/01/2015", [{:question_text=>"Location", :operator_text=>"Filled", :value=>""}], ["Last login date: Before 9/20/2027"]], filters.values

    new_view = AdminView.create!(:program => programs(:albers), :title => "Sample Rejected View", :filter_params => AdminView.convert_to_yaml({
        :roles_and_status => {role_filter_1: {type: :include, :roles => RoleConstants::DEFAULT_ROLE_NAMES}, :signup_state => {:accepted_not_signed_up_users => "accepted_not_signed_up_users", :added_not_signed_up_users => "added_not_signed_up_users", :signed_up_users => "signed_up_users"}},
        :connection_status => {:status => UsersIndexFilters::Values::CONNECTED, :availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}, :mentoring_requests => {:mentees => "2", :mentors => "4"}, :meeting_requests => {:mentees => "2", :mentors => "4"}, :meetingconnection_status => "2", mentor_recommendations: {mentees: "1"}, :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}}, :meeting_requests => {:mentors => {:request_duration => "1", "1" => "10", "2" => "", "3" => ""}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "01/01/2015"}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}}, :mentor_recommendations => {:mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" => ""}}}},
        :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
        :others => {:tags => ""},
        :timeline => {:timeline_questions => {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :type =>"2" ,:value => "9/20/2027"}}}
    }))
    new_view.stubs(:can_show_mentor_recommendation_filter?).returns(true)
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "User Signup Status", "Mentoring Connection Status", "Mentor Availability", "Meeting Requests", "Mentoring Requests", "Users who are", "Mentor Recommendations", "Profile", "Timeline"], filters.keys
    assert_equal ["Administrator, Mentor and Student", ["Users who have not signed up after being added", "Users who have not signed up after being accepted", "Signed up users"], "Currently connected", "Have connection slots less than 2", ["Sent meeting requests that are pending action After 01/01/2015", "Received meeting requests and rejected at least one request In last 10 days"], ["Sent mentoring requests that are pending action After 01/01/2015", "Received mentoring requests and rejected at least one request Before 01/01/2015"], "Connected (Part of at least one meeting request which is accepted) Before 01/01/2015", "Received mentor recommendations Before 01/01/2015", [{:question_text=>"Location", :operator_text=>"Filled", :value=>""}], ["Last login date: Before 9/20/2027"]], filters.values


    ### Ignore meeting request filters when calendar feature is disabled ###
    new_view = AdminView.create!(:program => programs(:albers), :title => "Meeting Requests View", :filter_params => AdminView.convert_to_yaml({
      :roles_and_status => {role_filter_1: {type: :include, :roles => RoleConstants::DEFAULT_ROLE_NAMES}}, :connection_status => {:mentoring_requests => {:mentees => "", :mentors => ""}, :meeting_requests => {:mentees => "", :mentors => ""}, :meetingconnection_status => "2", :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "4", "1" => "", "2" => "", "3" => ""}}}}}))
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "Users who are"], filters.keys
    assert_equal ["Administrator, Mentor and Student", "Connected (Part of at least one meeting request which is accepted) "], filters.values

    # create new role in program and create view
    programs(:albers).roles.create(:name => "board_of_advisor")
    new_view = AdminView.create!(:program => programs(:albers), :title => "New Role Users", :filter_params => AdminView.convert_to_yaml({
      :roles_and_status => {role_filter_1: {type: :include, :roles => ["board_of_advisor"]}}, :connection_status => {:mentoring_requests => {:mentees => "", :mentors => ""}, :meeting_requests => {:mentees => "", :mentors => ""}, :meetingconnection_status => "", :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "", "1" => "", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "", "1" => "", "2" => "", "3" => ""}}}}}))
    filters = new_view.get_applied_filters
    assert_equal ["Roles"], filters.keys
    assert_equal ["Board of advisor"], filters.values

    new_view = AdminView.create!(:program => programs(:albers), :title => "Translation Test", :filter_params => AdminView.convert_to_yaml({
      :roles_and_status => {role_filter_1: {type: :include, :roles => RoleConstants::DEFAULT_ROLE_NAMES}, :state => {"active"=>"active", "pending"=>"pending", "suspended"=>"suspended"}}, :connection_status => {:mentoring_requests => {:mentees => "", :mentors => ""}, :meeting_requests => {:mentees => "", :mentors => ""}, :meetingconnection_status => "", :advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "", "1" => "", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "", "1" => "", "2" => "", "3" => ""}}, :meetingconnection_status => {:both => {:request_duration => "", "1" => "", "2" => "", "3" => ""}}}}}))
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "User Status"], filters.keys
    assert_equal ["Administrator, Mentor and Student", "Active, Unpublished, Deactivated"], filters.values

    # For profile filters
    profile_question_id = profile_questions(:single_choice_q).id.to_s
    new_view = AdminView.create!(program: programs(:albers), title: "Choice Based Test", filter_params: AdminView.convert_to_yaml({
      profile: {questions: {questions_1: {question: profile_question_id, operator: "7", value: "", choice: "#{question_choices(:single_choice_q_1).id}"}, questions_2: {question: profile_question_id, operator: "10", value: "Opt3", choice: ""}}, score: {operator: "", value: ""}, mandatory_filter: ""},
      roles_and_status: {role_filter_1: {type: :include, roles: RoleConstants::DEFAULT_ROLE_NAMES}, state: {"active"=>"active"}}, connection_status: {mentoring_requests: {mentees: "", mentors: ""}, meeting_requests: {mentees: "", mentors: ""}, meetingconnection_status: "", advanced_options: {mentoring_requests: {mentors: {request_duration: "", "1" => "", "2" => "", "3" => ""}, mentees: {request_duration: "", "1" => "", "2" => "", "3" => ""}}, meeting_requests: {mentors: {request_duration: "", "1" => "", "2" => "", "3" => ""}, mentees: {request_duration: "", "1" => "", "2" => "", "3" => ""}}, meetingconnection_status: {both: {request_duration: "", "1" => "", "2" => "", "3" => ""}}}}}))
    filters = new_view.get_applied_filters
    assert_equal ["Roles", "User Status", "Profile"], filters.keys
    assert_equal ["Administrator, Mentor and Student", "Active", [{:question_text=>"What is your name", :operator_text=>"Contains Any Of", :value=>"opt_1"}, {:question_text=>"What is your name", :operator_text=>"Matches", :value=>"Opt3"}]], filters.values

  end

  def test_is_program_view
    prog_admin_view = programs(:albers).admin_views.first
    assert prog_admin_view.is_program_view?

    org_admin_view = programs(:org_primary).admin_views.first
    assert_false org_admin_view.is_program_view?
  end

  def test_is_organization_view
    prog_admin_view = programs(:albers).admin_views.first
    assert_false prog_admin_view.is_organization_view?

    org_admin_view = programs(:org_primary).admin_views.first
    assert org_admin_view.is_organization_view?
  end

  def test_organization
    prog_admin_view = programs(:albers).admin_views.first
    assert_equal programs(:org_primary), prog_admin_view.organization

    org_admin_view = programs(:org_primary).admin_views.first
    assert_equal programs(:org_primary), org_admin_view.organization
  end

  def test_range_intersection
    # Test an inclusive range
    range = 5..10
    tests = {
      1..4   => nil,     # before
      11..15 => nil,     # after
      1..6   => 5..6,    # overlap_begin
      9..15  => 9..10,   # overlap_end
      1..5   => 5..5,    # overlap_begin_edge
      10..15 => 10..10,  # overlap_end_edge
      5..10  => 5..10,   # overlap_all
      6..9   => 6..9,    # overlap_inner
      1...5  => nil,     # before             (exclusive range)
      1...7  => 5..6,    # overlap_begin      (exclusive range)
      1...6  => 5..5,    # overlap_begin_edge (exclusive range)
      5...11 => 5..10,   # overlap_all        (exclusive range)
      6...10 => 6..9,    # overlap_inner      (exclusive range)
    }
    tests.each do |other, expected|
      assert_dynamic_expected_nil_or_equal expected, range & other
    end
    range = 1...10
    tests = {
      5..15 => 5..9       #overlap_end
    }
    tests.each do |other, expected|
      assert_dynamic_expected_nil_or_equal expected, range & other
    end
  end

  def test_profile_questions_for_roles
    program = programs(:albers)
    admin_view = program.admin_views.first
    opts = {:default => false, :skype => program.organization.skype_enabled?, :dont_include_section => true}
    options = {}
    [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].each do |role|
      options[role] = program.profile_questions_for(role, opts)
    end
    assert_equal options, admin_view.profile_questions_for_roles
  end

  def test_languages_filter_enabled
    program = programs(:albers)
    admin_view = program.admin_views.first
    # see test case for Organization#languages_filter_enabled? in organization_test.rb
    admin_view.organization.stubs(:languages_filter_enabled?).returns(true)
    assert admin_view.languages_filter_enabled?
    admin_view.organization.stubs(:languages_filter_enabled?).returns(false)
    assert_false admin_view.languages_filter_enabled?
  end

  def test_CSV_language_column_support
    admin_view = programs(:albers).admin_views.first
    members(:mentor_10).update_attribute(:state, Member::Status::DORMANT)
    expected_language_values = [AdminViewColumn::LANGUAGE_NOT_SET_DISPLAY, Language.for_english.title, "Telugu", "Hindi"]
    assert_equal_unordered expected_language_values, User.connection.select_all(admin_view.users_scope).map{|hsh| hsh[AdminViewColumn::Columns::Key::LANGUAGE]}.uniq
    assert_equal_unordered expected_language_values, Member.connection.select_all(admin_view.members_scope).map{|hsh| hsh[AdminViewColumn::Columns::Key::LANGUAGE]}.uniq
  end

  def test_language_columns_exists
    admin_view = programs(:albers).admin_views.first
    assert_false admin_view.language_columns_exists?
    get_tmp_language_column(admin_view).save
    assert admin_view.language_columns_exists?
  end

  def test_get_language_applied_filters
    admin_view = programs(:albers).admin_views.first
    admin_view.stubs(:languages_filter_enabled?).returns(true)
    hindi_id = Language.where(title: "Hindi")[0].id.to_s
    telugu_id = Language.where(title: "Telugu")[0].id.to_s
    english_id = "0"
    hash_options = {}
    admin_view.send(:get_language_applied_filters, {}, hash_options = {})
    assert_equal_hash({}, hash_options)
    admin_view.send(:get_language_applied_filters, {AdminViewColumn::Columns::Key::LANGUAGE => nil}, hash_options = {})
    assert_equal_hash({}, hash_options)
    admin_view.send(:get_language_applied_filters, {AdminViewColumn::Columns::Key::LANGUAGE => [english_id]}, hash_options = {})
    assert_equal_hash({"Language used"=>["English"]}, hash_options)
    admin_view.send(:get_language_applied_filters, {AdminViewColumn::Columns::Key::LANGUAGE => [hindi_id]}, hash_options = {})
    assert_equal_hash({"Language used"=>["Hindi"]}, hash_options)
    admin_view.send(:get_language_applied_filters, {AdminViewColumn::Columns::Key::LANGUAGE => [english_id, hindi_id]}, hash_options = {})
    assert_equal_hash({"Language used"=>["English", "Hindi"]}, hash_options)
    admin_view.send(:get_language_applied_filters, {AdminViewColumn::Columns::Key::LANGUAGE => [telugu_id, hindi_id]}, hash_options = {})
    assert_equal_hash({"Language used"=>["Hindi", "Telugu"]}, hash_options)
    admin_view.send(:get_language_applied_filters, {AdminViewColumn::Columns::Key::LANGUAGE => [telugu_id, hindi_id, english_id]}, hash_options = {})
    assert_equal_hash({"Language used"=>["English", "Hindi", "Telugu"]}, hash_options)
    admin_view.stubs(:languages_filter_enabled?).returns(false)
    admin_view.send(:get_language_applied_filters, {AdminViewColumn::Columns::Key::LANGUAGE => [english_id]}, hash_options = {})
    assert_equal_hash({}, hash_options)
  end

  def test_apply_language_filtering
    program = programs(:albers)
    admin_view = program.admin_views.first
    filter_params = {language: ['1','2']}
    with_options = {}
    state_key = 'members.'
    admin_view.stubs(:languages_filter_enabled?).returns(true)
    admin_view.apply_language_filtering!(filter_params, with_options, state_key)
      assert_equal [0,2], with_options['members.state']
    assert_equal_unordered [1, 2], with_options['members.member_language_id']
    with_options['members.state'] = [0, 3]
    admin_view.apply_language_filtering!(filter_params, with_options, state_key)
    assert_equal [0], with_options['members.state']
    with_options['members.state'] = [3]
    admin_view.apply_language_filtering!(filter_params, with_options, state_key)
    assert_equal "i", with_options['members.state']
    with_options = {}
    with_options['members.state'] = [0, 3]
    admin_view.stubs(:languages_filter_enabled?).returns(false)
    admin_view.apply_language_filtering!(filter_params, with_options, state_key)
    assert_equal [0, 3], with_options['members.state']
    assert_nil with_options['members.member_language_id']
    admin_view.stubs(:languages_filter_enabled?).returns(true)
    filter_params = {language: '1'}
    admin_view.apply_language_filtering!(filter_params, with_options, state_key)
    assert_equal [0], with_options['members.state']
    assert_equal 1, with_options['members.member_language_id']
  end

  def test_filter_names
    org_admin_view = programs(:org_primary).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS)
    assert_equal_unordered [:member_status, :profile, :program_role_state, :language], org_admin_view.filter_names

    prog_admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    assert_equal_unordered [:roles_and_status, :connection_status, :profile, :others, :timeline, :language, :survey], prog_admin_view.filter_names
  end

  def test_es_search_condition
    program = programs(:albers)
    admin_view = program.admin_views.first
    value = '5'

    assert_equal 5, admin_view.send(:es_search_condition, AdminView::KendoNumericOperators::EQUAL, value)
    assert_equal 5, admin_view.send(:es_search_condition, AdminView::KendoNumericOperators::NOT_EQUAL, value)
    assert_equal 5..1000000, admin_view.send(:es_search_condition, AdminView::KendoNumericOperators::GREATER_OR_EQUAL, value)
    assert_equal 6..1000000, admin_view.send(:es_search_condition, AdminView::KendoNumericOperators::GREATER, value)
    assert_equal 0..5, admin_view.send(:es_search_condition, AdminView::KendoNumericOperators::LESS_OR_EQUAL, value)
    assert_equal 0..4, admin_view.send(:es_search_condition, AdminView::KendoNumericOperators::LESS, value)
  end

  def test_filter_profile_score
    program = programs(:albers)
    admin_view = program.admin_views.first
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    suspend_user(users(:f_user))
    inactive_user = users(:f_user)
    users_ids = [f_admin.id, f_mentor.id, f_student.id, inactive_user.id]
    value = '15'

    assert_equal_unordered [f_admin.id, f_student.id, inactive_user.id], admin_view.send(:filter_profile_score, users_ids, AdminView::KendoNumericOperators::EQUAL, value)
    assert_equal_unordered [f_mentor.id], admin_view.send(:filter_profile_score, users_ids, AdminView::KendoNumericOperators::NOT_EQUAL, value)
    assert_equal_unordered [f_admin.id, f_mentor.id, f_student.id, inactive_user.id], admin_view.send(:filter_profile_score, users_ids, AdminView::KendoNumericOperators::GREATER_OR_EQUAL, value)
    assert_equal_unordered [f_mentor.id], admin_view.send(:filter_profile_score, users_ids, AdminView::KendoNumericOperators::GREATER, value)
    assert_equal_unordered [f_admin.id, f_student.id, inactive_user.id], admin_view.send(:filter_profile_score, users_ids, AdminView::KendoNumericOperators::LESS_OR_EQUAL, value)
    assert_equal_unordered [], admin_view.send(:filter_profile_score, users_ids, AdminView::KendoNumericOperators::LESS, value)
  end

  def test_filter_mentoring_mode
    programs(:albers).enable_feature(FeatureName::CALENDAR)
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    programs(:albers).allow_mentoring_mode_change = Program::MENTORING_MODE_CONFIG::EDITABLE
    programs(:albers).save!

    filter_params = {:roles_and_status => {role_filter_1: {type: :include, :roles => "#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME},#{RoleConstants::STUDENT_NAME}".split(",")}},
      :connection_status => {:status => "", :availability => {:operator => "", :value => ""}, :mentoring_model_preference => User::MentoringMode::ONE_TIME},
      :profile => {:questions => {:questions_1 => {:question => "", :operator => "", :value => ""}}, :score => {:operator => "", :value => ""}},
      :others => {:tags => ""}
    }

    admin_view = programs(:albers).admin_views.create!(:title => "Sample Test View", :filter_params => AdminView.convert_to_yaml(filter_params), :default_view => AdminView::EDITABLE_DEFAULT_VIEWS.first)
    users_ids = admin_view.generate_view("", "", false)
    users_ids.each do |user_id|
      assert User::MentoringMode.one_time_sanctioned.include?(User.find_by(id: user_id).mentoring_mode)
    end

    filter_params = {:roles_and_status => {role_filter_1: {type: :include, :roles => "#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME},#{RoleConstants::STUDENT_NAME}".split(',')}},
      :connection_status => {:status => "", :availability => {:operator => "", :value => ""}, :mentoring_model_preference => User::MentoringMode::ONGOING},
      :profile => {:questions => {:questions_1 => {:question => "", :operator => "", :value => ""}}, :score => {:operator => "", :value => ""}},
      :others => {:tags => ""}
    }

    admin_view = programs(:albers).admin_views.create!(:title => "Sample Test View 1", :filter_params => AdminView.convert_to_yaml(filter_params), :default_view => AdminView::EDITABLE_DEFAULT_VIEWS.last)
    users_ids = admin_view.generate_view("", "", false)
    users_ids.each do |user_id|
      assert User::MentoringMode.ongoing_sanctioned.include?(User.find_by(id: user_id).mentoring_mode)
    end

  end

  def test_admin_view_favourite_validations
    admin_view = programs(:albers).admin_views.last
    assert_false admin_view.favourite
    admin_view.set_favourite!
    assert_not_nil admin_view.reload.favourited_at
    assert admin_view.favourite
    assert_equal AdminView.get_admin_views_ordered(programs(:albers).admin_views).first, admin_view
    admin_view.unset_favourite!
    assert_false admin_view.favourite
    assert_nil admin_view.reload.favourited_at
  end

  def test_favourite_image_path
    admin_view = programs(:albers).admin_views.last
    assert_equal "fa fa-star-o", admin_view.favourite_image_path
    admin_view = programs(:albers).admin_views.first
    assert_equal "fa fa-star", admin_view.favourite_image_path
  end

  def test_set_favourite
    admin_view = programs(:albers).admin_views.last
    assert_false admin_view.favourite
    admin_view.set_favourite!
    assert admin_view.reload.favourite
  end

  def test_unset_favourite
    admin_view = programs(:albers).admin_views.first
    assert admin_view.favourite
    admin_view.unset_favourite!
    assert_false admin_view.reload.favourite
  end

  def test_get_admin_views_ordered
    new_view = new_view = AdminView.create!(:program => programs(:albers), :title => "Sample View", :filter_params => AdminView.convert_to_yaml({
        :roles_and_status => {role_filter_1: {type: :include, :roles => RoleConstants::DEFAULT_ROLE_NAMES}, :signup_state => {:accepted_not_signed_up_users => "accepted_not_signed_up_users", :added_not_signed_up_users => "added_not_signed_up_users", :signed_up_users => "signed_up_users"}},
        :connection_status => {:status => UsersIndexFilters::Values::CONNECTED, :availability => {:operator => AdminViewsHelper::QuestionType::HAS_LESS_THAN.to_s, :value => 2}},
        :profile => {:questions => {:question_1 => {:question => "3", :operator => AdminViewsHelper::QuestionType::ANSWERED.to_s, :value => ""}}},
        :others => {:tags => ""},
        :timeline => {:timeline_questions => {:question_1 => {:question => AdminView::TimelineQuestions::LAST_LOGIN_DATE.to_s, :type =>"2" ,:value => "9/20/2027"}}}
    }))
    assert_equal AdminView.get_admin_views_ordered(programs(:albers).admin_views).last, new_view
    new_view.set_favourite!
    assert_equal AdminView.get_admin_views_ordered(programs(:albers).reload.admin_views).first, new_view
  end

  def test_mandatory_views
    program = programs(:albers)
    expected_output = [{:title => "All Users", :admin_view => {:roles_and_status => {role_filter_1: {type: :include, :roles => [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, 'user']}}}, :default_view => AbstractView::DefaultType::ALL_USERS},
                       {:title => "All Administrators", :admin_view => {:roles_and_status => {role_filter_1: {type: :include, :roles => [RoleConstants::ADMIN_NAME]}}}, :default_view => AbstractView::DefaultType::ALL_ADMINS},
                       {:title => "All Mentors", :admin_view => {:roles_and_status => {role_filter_1: {type: :include, :roles => [RoleConstants::MENTOR_NAME]}}}, :default_view => AbstractView::DefaultType::MENTORS},
                       {:title => "All Students", :admin_view => {:roles_and_status => {role_filter_1: {type: :include, :roles => [RoleConstants::STUDENT_NAME]}}}, :default_view => AbstractView::DefaultType::MENTEES}]
    assert_equal expected_output, AdminView::DefaultAdminView.mandatory_views(program)
  end

  def test_mandatory_views_for_portal
    program = programs(:primary_portal)
    expected_output = [{:title => "All Users", :admin_view => {:roles_and_status=>{role_filter_1: {type: :include, :roles=>[RoleConstants::ADMIN_NAME, RoleConstants::EMPLOYEE_NAME]}}}, :default_view => AbstractView::DefaultType::ALL_USERS},
                       {:title => "All Administrators", :admin_view => {:roles_and_status=>{role_filter_1: {type: :include, :roles=>[RoleConstants::ADMIN_NAME]}}}, :default_view => AbstractView::DefaultType::ALL_ADMINS},
                       {:title => "All Employees", :admin_view => {:roles_and_status=>{role_filter_1: {type: :include, :roles=>[RoleConstants::EMPLOYEE_NAME]}}}, :default_view => AbstractView::DefaultType::EMPLOYEES}]
    assert_equal expected_output, AdminView::DefaultAdminView.mandatory_views(program)
  end

  def test_get_meeting_connection_status_range
    admin_view = AdminView.first
    filter_params = {:advanced_options => {:meetingconnection_status => {:both => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" =>""}}}}
    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..convert_to_date("01/01/2015"), admin_view.get_connection_status_range(filter_params, :meetingconnection_status, :both)
    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..(AdminView::TimelineQuestions::ENDING_DATE), admin_view.get_connection_status_range({}, :meetingconnection_status, :both)
  end

  def test_get_mentoring_request_range_for_mentors
    admin_view = AdminView.first
    filter_params = {:advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" =>""}}}}
    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..convert_to_date("01/01/2015"), admin_view.get_connection_status_range(filter_params, :mentoring_requests, :mentors)

    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..(AdminView::TimelineQuestions::ENDING_DATE), admin_view.get_connection_status_range({}, :mentoring_requests, :mentors)
  end

  def test_get_meeting_request_range_for_mentees
    admin_view = AdminView.first
    filter_params = {:advanced_options => {:meeting_requests => {:mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" =>""}}}}
    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..convert_to_date("01/01/2015"), admin_view.get_connection_status_range(filter_params, :meeting_requests, :mentees)

    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..(AdminView::TimelineQuestions::ENDING_DATE), admin_view.get_connection_status_range({}, :meeting_requests, :mentees)
  end

  def test_get_meeting_request_range_for_mentors
    admin_view = AdminView.first
    filter_params = {:advanced_options => {:meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" =>""}}}}
    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..convert_to_date("01/01/2015"), admin_view.get_connection_status_range(filter_params, :meeting_requests, :mentors)

    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..(AdminView::TimelineQuestions::ENDING_DATE), admin_view.get_connection_status_range({}, :meeting_requests, :mentors)
  end

  def test_get_mentoring_request_range_for_mentees
    admin_view = AdminView.first
    filter_params = {:advanced_options => {:mentoring_requests => {:mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" =>""}}}}
    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..convert_to_date("01/01/2015"), admin_view.get_connection_status_range(filter_params, :mentoring_requests, :mentees)

    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..(AdminView::TimelineQuestions::ENDING_DATE), admin_view.get_connection_status_range({}, :mentoring_requests, :mentees)
  end

  def test_get_mentor_recommendations_range
    admin_view = AdminView.first
    filter_params = {:advanced_options => {:mentor_recommendations => {:mentees => {:request_duration => "2", "1" => "", "2" => "01/01/2015", "3" =>""}}}}
    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..convert_to_date("01/01/2015"), admin_view.get_connection_status_range(filter_params, :mentor_recommendations, :mentees)

    assert_equal (AdminView::TimelineQuestions::STARTING_DATE)..(AdminView::TimelineQuestions::ENDING_DATE), admin_view.get_connection_status_range({}, :mentor_recommendations, :mentees)
  end

  def test_sort_by_mentoring_mode_column
    admin_view = AdminView.first
    user_ids = [users(:f_mentor).id, users(:robert).id, users(:student_1).id, users(:student_6).id]

    users(:f_mentor).update_attribute(:mentoring_mode, User::MentoringMode::ONGOING)
    users(:robert).update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)
    users(:student_1).update_attribute(:mentoring_mode, User::MentoringMode::NOT_APPLICABLE)

    assert_equal users(:student_6).mentoring_mode, User::MentoringMode::ONE_TIME_AND_ONGOING

    assert_equal [users(:student_1), users(:robert), users(:f_mentor), users(:student_6)].collect(&:id), admin_view.sort_users_or_members(user_ids, AdminViewColumn::Columns::Key::MENTORING_MODE, "asc", User, {})

    assert_equal [users(:student_6), users(:f_mentor), users(:robert), users(:student_1)].collect(&:id), admin_view.sort_users_or_members(user_ids, AdminViewColumn::Columns::Key::MENTORING_MODE, "desc", User, {})
  end

  def test_sort_by_mentoring_request_column
    admin_view = AdminView.first
    admin_view.update_attributes!(:filter_params => admin_view.filter_params_hash.merge({:connection_status => {:advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "100", "2" => "", "3" => ""}}}}}).to_yaml)

    mentor_ids = [users(:f_mentor).id, users(:robert).id]
    student_ids = [users(:student_1).id, users(:student_6).id]

    user_ids = student_ids + mentor_ids

    assert_equal 0, users(:f_mentor).sent_mentor_requests.size
    assert_equal 0, users(:robert).sent_mentor_requests.size
    assert_equal 2, users(:student_1).sent_mentor_requests.size
    assert_equal 1, users(:student_6).sent_mentor_requests.size

    assert_equal [users(:f_mentor), users(:robert), users(:student_6), users(:student_1)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_sent_v1", "asc", {})
    assert_equal [users(:student_1), users(:student_6), users(:f_mentor), users(:robert)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_sent_v1", "desc", {})

    assert_equal 15, users(:f_mentor).received_mentor_requests.size
    assert_equal 5, users(:robert).received_mentor_requests.size
    assert_equal 0, users(:student_1).received_mentor_requests.size
    assert_equal 0, users(:student_6).received_mentor_requests.size

    assert_equal [users(:f_mentor), users(:robert), users(:student_1), users(:student_6)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_received_v1", "desc", {})
    assert_equal [users(:student_1), users(:student_6), users(:robert), users(:f_mentor)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_received_v1", "asc", {})

    assert_equal 0, users(:f_mentor).sent_mentor_requests.active.size
    assert_equal 0, users(:robert).sent_mentor_requests.size
    assert_equal 2, users(:student_1).sent_mentor_requests.size
    assert_equal 1, users(:student_6).sent_mentor_requests.size

    assert_equal [users(:f_mentor), users(:robert), users(:student_6), users(:student_1)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_sent_and_pending_v1", "asc", {})
    assert_equal [users(:student_1), users(:student_6), users(:f_mentor), users(:robert)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_sent_and_pending_v1", "desc", {})

    assert_equal 11, users(:f_mentor).received_mentor_requests.active.size
    assert_equal 4, users(:robert).received_mentor_requests.active.size
    assert_equal 0, users(:student_1).received_mentor_requests.active.size
    assert_equal 0, users(:student_6).received_mentor_requests.active.size

    assert_equal [users(:f_mentor), users(:robert), users(:student_1), users(:student_6)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_received_and_pending_v1", "desc", {})
    assert_equal [users(:student_1), users(:student_6), users(:robert), users(:f_mentor)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_received_and_pending_v1", "asc", {})

    assert_equal 4, users(:f_mentor).received_mentor_requests.rejected.size
    assert_equal 0, users(:robert).received_mentor_requests.rejected.size
    assert_equal 0, users(:student_1).received_mentor_requests.rejected.size
    assert_equal 0, users(:student_6).received_mentor_requests.rejected.size

    assert_equal [users(:f_mentor), users(:robert), users(:student_1), users(:student_6)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_received_and_rejected", "desc", {})
    assert_equal [users(:robert), users(:student_1), users(:student_6), users(:f_mentor)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_received_and_rejected", "asc", {})

    users(:robert).received_mentor_requests.last.update_attributes!(status: AbstractRequest::Status::CLOSED, closed_at: Time.now)
    assert_equal 1, users(:robert).received_mentor_requests.closed.size
    assert_equal 0, users(:f_mentor).received_mentor_requests.closed.size
    assert_equal 0, users(:student_1).received_mentor_requests.closed.size
    assert_equal 0, users(:student_6).received_mentor_requests.closed.size

    assert_equal [users(:robert), users(:f_mentor), users(:student_1), users(:student_6)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_received_and_closed", "desc", {})
    assert_equal [users(:f_mentor), users(:student_1), users(:student_6), users(:robert)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_received_and_closed", "asc", {})

    range = 100.days.ago..Time.now
    date_range = {:mentoring_requests_sent => range}

    assert_equal 0, users(:f_mentor).sent_mentor_requests.created_in_date_range(range).size
    assert_equal 0, users(:robert).sent_mentor_requests.created_in_date_range(range).size
    assert_equal 2, users(:student_1).sent_mentor_requests.created_in_date_range(range).size
    assert_equal 1, users(:student_6).sent_mentor_requests.created_in_date_range(range).size

    assert_equal [users(:f_mentor), users(:robert), users(:student_6), users(:student_1)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_sent_v1", "asc", date_range)
    assert_equal [users(:student_1), users(:student_6), users(:f_mentor), users(:robert)], admin_view.sort_by_mentoring_request_column(user_ids, "mentoring_requests_sent_v1", "desc", date_range)
  end

  def test_sort_by_meeting_request_column
    admin_view = AdminView.first
    admin_view.update_attributes!(:filter_params => admin_view.filter_params_hash.merge({:connection_status => {:advanced_options => {:meeting_requests => {:mentors => {:request_duration => "1", "1" => "100", "2" => "", "3" => ""}}}}}).to_yaml)

    mentor_ids = [users(:f_mentor).id, users(:robert).id]
    student_ids = [users(:f_student).id, users(:mkr_student).id]

    user_ids = student_ids + mentor_ids

    assert_equal 0, users(:f_mentor).sent_meeting_requests.size
    assert_equal 0, users(:robert).sent_meeting_requests.size
    assert_equal 2, users(:f_student).sent_meeting_requests.size
    assert_equal 4, users(:mkr_student).sent_meeting_requests.size
    assert_equal [users(:f_mentor), users(:robert), users(:f_student), users(:mkr_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_sent_v1", "asc", {})
    assert_equal [users(:mkr_student), users(:f_student), users(:f_mentor), users(:robert)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_sent_v1", "desc", {})

    assert_equal 5, users(:f_mentor).received_meeting_requests.size
    assert_equal 2, users(:robert).received_meeting_requests.size
    assert_equal 0, users(:f_student).received_meeting_requests.size
    assert_equal 0, users(:mkr_student).received_meeting_requests.size

    assert_equal [users(:f_mentor), users(:robert), users(:f_student), users(:mkr_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_v1", "desc", {})
    assert_equal [users(:f_student), users(:mkr_student), users(:robert), users(:f_mentor)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_v1", "asc", {})

    assert_equal 0, users(:f_mentor).sent_meeting_requests.active.size
    assert_equal 0, users(:robert).sent_meeting_requests.active.size
    assert_equal 1, users(:f_student).sent_meeting_requests.active.size
    assert_equal 0, users(:mkr_student).sent_meeting_requests.active.size

    assert_equal [users(:f_mentor), users(:robert), users(:mkr_student), users(:f_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_sent_and_pending_v1", "asc", {})
    assert_equal [users(:f_student), users(:f_mentor), users(:robert), users(:mkr_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_sent_and_pending_v1", "desc", {})

    assert_equal 1, users(:f_mentor).received_meeting_requests.active.size
    assert_equal 1, users(:robert).received_meeting_requests.active.size
    assert_equal 0, users(:f_student).received_meeting_requests.active.size
    assert_equal 0, users(:mkr_student).received_meeting_requests.active.size

    assert_equal [users(:f_mentor), users(:robert), users(:f_student), users(:mkr_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_and_pending_v1", "desc", {})
    assert_equal [users(:f_student), users(:mkr_student), users(:f_mentor), users(:robert)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_and_pending_v1", "asc", {})

    assert_equal 0, users(:f_mentor).sent_meeting_requests.accepted.size
    assert_equal 0, users(:robert).sent_meeting_requests.accepted.size
    assert_equal 0, users(:f_student).sent_meeting_requests.accepted.size
    assert_equal 4, users(:mkr_student).sent_meeting_requests.accepted.size

    assert_equal [users(:mkr_student), users(:f_student), users(:f_mentor), users(:robert)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_sent_and_accepted_v1", "desc", {})
    assert_equal [users(:f_student), users(:f_mentor), users(:robert), users(:mkr_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_sent_and_accepted_v1", "asc", {})

    assert_equal 4, users(:f_mentor).received_meeting_requests.accepted.size
    assert_equal 0, users(:robert).received_meeting_requests.accepted.size
    assert_equal 0, users(:f_student).received_meeting_requests.accepted.size
    assert_equal 0, users(:mkr_student).received_meeting_requests.accepted.size

    assert_equal [users(:f_mentor), users(:f_student), users(:robert), users(:mkr_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_and_accepted_v1", "desc", {})
    assert_equal [users(:f_student), users(:robert), users(:mkr_student), users(:f_mentor)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_and_accepted_v1", "asc", {})

    assert_equal 0, users(:f_mentor).received_meeting_requests.rejected.size
    assert_equal 1, users(:robert).received_meeting_requests.rejected.size
    assert_equal 0, users(:f_student).received_meeting_requests.rejected.size
    assert_equal 0, users(:mkr_student).received_meeting_requests.rejected.size
    assert_equal [users(:robert), users(:f_student), users(:f_mentor), users(:mkr_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_and_rejected", "desc", {})
    assert_equal [users(:f_student), users(:f_mentor), users(:mkr_student), users(:robert)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_and_rejected", "asc", {})

    users(:f_mentor).received_meeting_requests.last.update_attributes!(status: AbstractRequest::Status::CLOSED, closed_at: Time.now)
    assert_equal 1, users(:f_mentor).received_meeting_requests.closed.size
    assert_equal 0, users(:robert).received_meeting_requests.closed.size
    assert_equal 0, users(:f_student).received_meeting_requests.closed.size
    assert_equal 0, users(:mkr_student).received_meeting_requests.closed.size
    assert_equal [users(:f_mentor), users(:f_student), users(:robert), users(:mkr_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_and_closed", "desc", {})
    assert_equal [users(:f_student), users(:robert), users(:mkr_student), users(:f_mentor)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_received_and_closed", "asc", {})

    range = 100.days.ago..Time.now
    date_range = {:mentoring_requests_sent => range}

    assert_equal 0, users(:f_mentor).sent_meeting_requests.created_in_date_range(range).size
    assert_equal 0, users(:robert).sent_meeting_requests.created_in_date_range(range).size
    assert_equal 2, users(:f_student).sent_meeting_requests.created_in_date_range(range).size
    assert_equal 4, users(:mkr_student).sent_meeting_requests.created_in_date_range(range).size

    assert_equal [users(:f_mentor), users(:robert), users(:f_student), users(:mkr_student)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_sent_v1", "asc", date_range)
    assert_equal [users(:mkr_student), users(:f_student), users(:f_mentor), users(:robert)], admin_view.sort_by_meeting_request_column(user_ids, "meeting_requests_sent_v1", "desc", date_range)
  end

  def test_get_users_with_profile_scores
    admin_view = programs(:albers).admin_views.first

    user_ids = [users(:f_admin).id, users(:f_mentor).id]

    users_with_profile_score = admin_view.send(:get_users_with_profile_scores, user_ids)
    assert_equal_unordered [users(:f_admin).id, users(:f_mentor).id], users_with_profile_score.collect(&:id).map(&:to_i)
    assert_equal_unordered [15, 59], users_with_profile_score.collect(&:profile_score_sum).map(&:to_i)

    # sort by asc
    user_ids = [users(:f_admin).id, users(:f_student).id, users(:f_mentor).id, users(:inactive_user).id]
    users_with_profile_score = admin_view.send(:get_users_with_profile_scores, user_ids, sort_order: "asc", sort_field: "profile_score_sum")
    ids = users_with_profile_score.collect(&:id).map(&:to_i)
    assert_equal_unordered [users(:f_student).id, users(:f_admin).id, users(:inactive_user).id], ids[0..-2]
    assert users(:f_mentor).id == ids[-1]
    assert_equal [15, 15, 15, 59], users_with_profile_score.collect(&:profile_score_sum).map(&:to_i)

    # sort by desc
    user_ids = [users(:f_admin).id, users(:f_student).id, users(:f_mentor).id, users(:inactive_user).id]
    users_with_profile_score = admin_view.send(:get_users_with_profile_scores, user_ids, sort_order: "desc", sort_field: "profile_score_sum")
    ids = users_with_profile_score.collect(&:id).map(&:to_i)
    assert_equal_unordered [users(:f_admin).id, users(:f_student).id, users(:inactive_user).id], ids[1..-1]
    assert users(:f_mentor).id == ids[0]
    assert_equal [59, 15, 15, 15], users_with_profile_score.collect(&:profile_score_sum).map(&:to_i)
  end

  def test_get_columns_of_question_type
    admin_view  = admin_views(:admin_views_1)
    admin_view_column = admin_view.admin_view_columns.last
    
    admin_view_column.update(profile_question_id: profile_questions(:string_q).id)
    assert_equal [admin_view_column.id], admin_view.reload.get_columns_of_question_type(0)

    admin_view_column.update(profile_question_id: profile_questions(:date_question).id)
    assert_equal [admin_view_column.id], admin_view.reload.get_columns_of_question_type(20)
  end

  def test_get_column_title_translation_keys
    portal = programs(:primary_portal)
    admin_view = portal.admin_views.first
    expected_hash = {program_title: "Programs", Meeting: "Meeting", Mentoring_Connection: "Connection", Mentoring_Connections: "Connections", Mentoring: "Mentoring", mentees: nil}
    assert_equal expected_hash, admin_view.send(:get_column_title_translation_keys)


    program = programs(:albers)
    admin_view = program.admin_views.first
    expected_hash = {program_title: "Programs", Meeting: "Meeting", Mentoring_Connection: "Mentoring Connection", Mentoring_Connections: "Mentoring Connections", Mentoring: "Mentoring", mentees: "students"}
    assert_equal expected_hash, admin_view.send(:get_column_title_translation_keys)
  end

  def test_is_part_of_bulk_match
    admin_view = admin_views(:admin_views_1)
    assert_false admin_view.is_part_of_bulk_match?
    program = programs(:albers)
    mentors_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTORS)
    assert mentors_view.is_part_of_bulk_match?
    mentees_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::MENTEES)
    assert mentees_view.is_part_of_bulk_match?
  end

  def test_get_user_ids_for_match_report
    admin_view = bulk_matches(:bulk_match_1).mentee_view
    admin_view.refresh_user_ids_cache
    AdminViewUserCache.any_instance.stubs(:user_ids).returns("1,2")
    assert_equal [1, 2], admin_view.get_user_ids_for_match_report

    admin_view = bulk_matches(:bulk_match_1).mentor_view
    admin_view.admin_view_user_cache.destroy!
    admin_view.reload
    AdminViewUserCache.any_instance.stubs(:user_ids).returns("1,2")
    assert_equal [1, 2], admin_view.get_user_ids_for_match_report
  end

  def test_get_filters_and_users
    admin_view = bulk_matches(:bulk_match_1).mentee_view
    AdminView.any_instance.stubs(:get_applied_filters).returns("filters")
    AdminView.any_instance.stubs(:generate_view).with("", "",false).returns("view users")
    AdminView.any_instance.stubs(:get_user_ids_for_match_report).returns("users")
    assert_equal ["filters", "users"], admin_view.get_filters_and_users({src: MatchReport::SettingsSrc::MATCH_REPORT})
    assert_equal ["filters", "view users"], admin_view.get_filters_and_users
  end

  private

  def convert_to_date(date_string)
    Date.strptime(date_string.strip, MeetingsHelper::DateRangeFormat.call).to_time
  end
end
