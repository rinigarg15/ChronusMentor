require_relative './../../test_helper.rb'

class RecentActivityHelperTest < ActionView::TestCase
  def setup
    super
    RecentActivityHelperTest.any_instance.stubs(:super_console?).returns(false)
    helper_setup
    self.expects(:organization_view?).at_least(0).returns(false)
    chronus_s3_utils_stub
  end

  def test_ra_link_to_user
    SecureRandom.stubs(:hex).returns(1)
    self.expects(:program_view?).at_least(0).returns(true)
    assert_equal link_to_user(users(:ram),
      :params => {:src => RecentActivityHelper::ANALYTICS_PARAM}),
        ra_link_to_user(users(:ram))

    assert_equal link_to_user(users(:rahim),
      :params => {:src => RecentActivityHelper::ANALYTICS_PARAM}),
        ra_link_to_user(users(:rahim))

    assert_equal link_to_user(users(:f_admin),
      :params => {:src => RecentActivityHelper::ANALYTICS_PARAM}),
        ra_link_to_user(users(:f_admin))
  end

  def test_admin_creation_creates_recent_activity
    self.expects(:program_view?).at_least(0).returns(true)
    program = programs(:albers)
    assert_difference('User.count') do
      assert_difference('RecentActivity.count') do
        create_user(:role_names => [RoleConstants::ADMIN_NAME], :program => program)
      end
    end

    ra = RecentActivity.last
    # Modify to assert that 'ago' string doesn't occur twice in the string.
    ra.update_attribute :created_at, 2.hours.ago
    new_admin = User.last
    string = format_recent_activity(ra, users(:f_admin))
    assert_match(/#{Regexp.escape new_admin.name}.*joined as an administrator/, string)
    assert_no_match(/About about/, string)
  end

  def test_user_activation_recent_activity
    self.expects(:program_view?).at_least(0).returns(true)
    student = users(:f_student)
    student.state_changer = users(:f_admin)
    student.state_change_reason = "Sorry for suspension"
    suspend_user(student)
    assert_difference('RecentActivity.count') do
      student.activate!
    end

    recent_activity = RecentActivity.last
    string = format_recent_activity(recent_activity, users(:f_mentor))
    assert_match users(:f_admin).name, string
    assert_match(/activated.*#{student.name}/, string)
  end

  def test_user_promotion_recent_activity
    self.expects(:program_view?).at_least(0).returns(true)
    user = users(:f_mentor)
    assert user.is_mentor?
    assert_difference('RecentActivity.count') do
      user.promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    end
    recent_activity = RecentActivity.last
    string = format_recent_activity(recent_activity, users(:f_admin))
    assert_match user.name, string
    assert_match "is now a mentor and administrator", string
  end

  def test_user_suspension_recent_activity
    self.expects(:program_view?).at_least(0).returns(true)
    assert_difference('RecentActivity.count') do
      users(:f_student).suspend_from_program!(users(:f_admin), "Abuse")
    end
    recent_activity = RecentActivity.last
    string = format_recent_activity(recent_activity, users(:f_mentor))
    assert_match users(:f_admin).name, string
    assert_match(/deactivated the membership .*#{users(:f_student).name}.* from #{users(:f_student).program.name}/, string)
  end

  def test_format_announcement_created_by_current_user
    self.expects(:program_view?).at_least(0).returns(true)
    create_announcement(:program => programs(:albers),
      :admin => users(:f_admin), :title => "Hello world announcement", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))

    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_match(/You posted a new announcement/, string)
    assert_match(/Hello world announcement/, string)
    # assert_no_select "div.more" # No body for announcement.
  end

  def test_format_announcement_created_by_another_user
    self.expects(:program_view?).at_least(0).returns(true)
    create_announcement(:program => programs(:albers),
      :admin => users(:ram), :title => "Hello world announcement",
      :body => "<b> my sincere message my sincere message my sincere message my sincere message </b>", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))

    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_match(/#{Regexp.escape(users(:ram).name)}.*posted a new announcement/, string)
    assert_match(/Hello world announcement/, string)
    assert_no_match(/my sincere message/,string)
    # assert_no_select "div.more"
  end

  def test_announcement_ra_cannot_be_see_unless_user_is_admin_or_has_common_role
    self.expects(:program_view?).at_least(0).returns(true)
    create_announcement(:program => programs(:albers),
      :admin => users(:ram), :title => "Hello world announcement",
      :body => "<b> my sincere message my sincere message my sincere message my sincere message </b>", :recipient_role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert_equal RecentActivityConstants::Target::ALL ,RecentActivity.last.target
    string = format_recent_activity(RecentActivity.last, users(:f_user))
    set_response_text(string)
    assert_nil string

    string = format_recent_activity(RecentActivity.last, users(:f_admin))
    assert_match(/#{Regexp.escape(users(:ram).name)}.*posted a new announcement/, string)
    assert_match(/Hello world announcement/, string)
    assert_no_match(/my sincere message/,string)
    # assert_no_select "div.more"
  end

  def test_forum_topic_creation
    self.expects(:program_view?).at_least(0).returns(true)
    program = programs(:albers)
    student_user = users(:f_student)
    mentor_user = users(:f_mentor)
    forum = forums(:common_forum)
    topic = create_topic(forum: forum, user: student_user, title: "Topic 1")
    recent_activity = topic.recent_activities.first

    content = format_recent_activity(recent_activity, mentor_user)
    assert_match(/#{student_user.name}.*started a conversation.*Topic 1.*'/, content)
    assert_select_helper_function "a[href='#{forum_topic_path(forum, topic, root: program.root, src: RecentActivityHelper::ANALYTICS_PARAM)}']", content, text: "View conversation"
    assert_select_helper_function "a[href='#{member_path(student_user, src: RecentActivityHelper::ANALYTICS_PARAM)}']", content, text: student_user.name

    content = format_recent_activity(recent_activity, student_user)
    assert_match(/You.*started a conversation.*Topic 1.*'/, content)
    assert_select_helper_function "a[href='#{forum_topic_path(forum, topic, root: program.root, src: RecentActivityHelper::ANALYTICS_PARAM)}']", content, text: "View conversation"

    Forum.any_instance.stubs(:can_be_accessed_by?).returns(false)
    assert_nil format_recent_activity(recent_activity, mentor_user)
    assert_nil format_recent_activity(recent_activity, student_user)
  end

  def test_forum_post_creation
    self.expects(:program_view?).at_least(0).returns(true)
    program = programs(:albers)
    student_user = users(:f_student)
    mentor_user = users(:f_mentor)
    forum = forums(:common_forum)
    topic = create_topic(forum: forum, title: "Topic 1")
    post = create_post(topic: topic, user: student_user, body: "Post 1")
    recent_activity = post.recent_activities.first

    content = format_recent_activity(recent_activity, mentor_user)
    assert_match(/#{student_user.name}.*posted in the conversation.*Topic 1.*'/, content)
    assert_select_helper_function "a[href='#{forum_topic_path(forum, topic, root: program.root, src: RecentActivityHelper::ANALYTICS_PARAM)}']", content, text: "View conversation"
    assert_select_helper_function "a[href='#{member_path(student_user, src: RecentActivityHelper::ANALYTICS_PARAM)}']", content, text: student_user.name

    content = format_recent_activity(recent_activity, student_user)
    assert_match(/You.*posted in the conversation.*Topic 1.*'/, content)
    assert_select_helper_function "a[href='#{forum_topic_path(forum, topic, root: program.root, src: RecentActivityHelper::ANALYTICS_PARAM)}']", content, text: "View conversation"

    Forum.any_instance.stubs(:can_be_accessed_by?).returns(false)
    assert_nil format_recent_activity(recent_activity, mentor_user)
    assert_nil format_recent_activity(recent_activity, student_user)
  end

  def test_mentor_request_activity
    student = users(:f_student)
    mentor = users(:f_mentor)
    self.expects(:program_view?).at_least(0).returns(true)
    @current_program = programs(:albers)

    # create mentor request
    mentor_req = create_mentor_request(:student => student, :mentor => mentor, :message => "<div class='inside'> Please help me</div>.<i> This is it </i><a></a>")

    string = format_recent_activity(RecentActivity.last, mentor)
    assert_match(/#{student.name}.* sent .*request for mentoring.* to You/, string)
    set_response_text(string)
    assert_select "a[href=?]", mentor_requests_path(:root => mentor.program.root, :src => RecentActivityHelper::ANALYTICS_PARAM, :mentor_request_id => mentor_req.id), :minimum => 2
    assert_select "a[href=?]", mentor_requests_path(:root => mentor.program.root, :src => RecentActivityHelper::ANALYTICS_PARAM, :mentor_request_id => mentor_req.id), :maximum => 3
    # assert_match /&lt;div class=&#39;inside&#39;&gt; Please help me&lt;\/div&gt;/, string

    # reject mentor request
    mentor_req.update_attributes(:response_text => "Sorry", :status => AbstractRequest::Status::REJECTED)
    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_match(/#{mentor.name}.*declined request for mentoring from.*#{student.name}/, string)

    string = format_recent_activity(RecentActivity.last, student)
    set_response_text(string)
    assert_match(/#{mentor.name}.*declined request for mentoring from You/, string)

    # withdraw mentor request
    allow_mentee_withdraw_mentor_request_for_program(programs(:albers),true)
    mentor_req.update_attributes(:response_text => "Sorry", :status => AbstractRequest::Status::WITHDRAWN)
    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_match(/#{student.name}.*withdrew request for mentoring sent to.*#{mentor.name}/, string)

    string = format_recent_activity(RecentActivity.last, mentor)
    set_response_text(string)
    assert_match(/#{student.name}.*withdrew request for mentoring sent to You/, string)
  end

  def test_mentor_request_acceptance
    self.expects(:program_view?).at_least(0).returns(true)
    student = users(:f_student)
    mentor = users(:f_mentor)
    mentor_req = create_mentor_request(:student => student, :mentor => mentor)

    mentor_req.mark_accepted!
    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_match(/#{mentor.name}.*accepted to connect with.*#{student.name}/, string)
  end

  # No problem should occur if mentor request's group is nil. We are doing this
  # check since group might get destroyed later.
  def test_mentor_request_acceptance_without_group_should_not_throw_error
    self.expects(:program_view?).at_least(0).returns(true)
    student = users(:f_student)
    mentor = users(:robert)

    no_grp_mentor_req = create_mentor_request(:student => student, :mentor => mentor)
    no_grp_mentor_req.mark_accepted!
    no_grp_mentor_req.group = nil
    no_grp_mentor_req.save!
    assert_nil no_grp_mentor_req.reload.group
    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_match(/#{mentor.name}.*accepted to connect with.*#{student.name}/, string)
    # assert_select "div.more", :count => 0
  end

  def test_create_mentor_request_ra_should_not_be_linked_to_mentor_requests_page_for_students
    self.expects(:program_view?).at_least(0).returns(true)
    student = users(:f_student)
    mentor = users(:f_mentor)

    create_mentor_request(:student => student, :mentor => mentor)
    string = format_recent_activity(RecentActivity.last, student)
    assert_match(/You sent a request for mentoring to .*#{mentor.name.capitalize}/, string)
    set_response_text(string)
    assert_no_select "a[href=\"#{mentor_requests_path(:src => RecentActivityHelper::ANALYTICS_PARAM)}\"]"
  end

  def test_format_membership_request
    self.expects(:program_view?).at_least(0).returns(true)
    create_membership_request
    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_match(/Good unique name.*sent.*request to join.*the program/, string)
  end

  def test_format_mentor_join
    self.expects(:program_view?).at_least(0).returns(true)
    user = create_user(:name => "Truss", :role_names => [RoleConstants::MENTOR_NAME])

    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /joined the program as a mentor/
      assert_select "a[href=?]", member_path(user.member, :src => RecentActivityHelper::ANALYTICS_PARAM),
          :text => user.name
    end
  end

  def test_format_mentor_add
    self.expects(:program_view?).at_least(0).returns(true)
    opts = {:program => programs(:albers), :created_by => users(:f_admin), :name => "Mentor Test", :email => "mentor@email.com", :role_names => [RoleConstants::MENTOR_NAME], :location_name => locations(:delhi).full_address}
    create_user(opts)

    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /has been added as a mentor in the program/
      assert_select "a[href=?]", member_path(User.last.member, :src => RecentActivityHelper::ANALYTICS_PARAM),
          :text => User.last.name
    end
  end

  def test_format_mentor_add_when_the_added_mentor_views_the_ra
    self.expects(:program_view?).at_least(0).returns(true)
    opts = {:program => programs(:albers), :created_by => users(:f_admin), :name => "Mentor Test", :email => "mentor@email.com", :role_names => [RoleConstants::MENTOR_NAME], :location_name => locations(:delhi).full_address}
    user_obj = create_user(opts)

    string = format_recent_activity(RecentActivity.last, user_obj)
    set_response_text(string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /You have been added as a mentor in the program/
    end
  end

  def test_format_admin_becoming_mentor
    self.expects(:program_view?).at_least(0).returns(true)
    # Ram adds mentor role to f_admin
    self.expects(:current_user).at_least(0).returns(users(:ram))
    assert_difference 'RecentActivity.count' do
      users(:f_admin).promote_to_role!(RoleConstants::MENTOR_NAME, users(:ram))
    end

    string = format_recent_activity(RecentActivity.last)
    set_response_text(string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /is now an administrator and mentor/
      assert_select "a[href=?]", member_path(members(:f_admin), :src => RecentActivityHelper::ANALYTICS_PARAM),
          :text => users(:f_admin).name
    end
  end

  def test_program_creation_recent_activity
    self.expects(:program_view?).at_least(0).returns(true)
    program = Program.create!(:name => "My new program", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, :root => 'Klass', :organization => programs(:org_primary))
    @current_program = program
    admin = create_user(:program => program, :role_names => [RoleConstants::ADMIN_NAME])
    program.set_owner!
    activity = program.recent_activities.find_by(action_type: RecentActivityConstants::Type::PROGRAM_CREATION)
    assert_equal RecentActivityConstants::Target::ADMINS, activity.target
    assert RecentActivity.for_admin(admin).include?(activity)
    string = format_recent_activity(activity, admin)
    set_response_text(string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content", /created the program/ do
        assert_select 'a', program.owner.name
        assert_select 'a', program.name
      end
      assert_select "a[href=?]", program_root_path(:root => program.root,:src => RecentActivityHelper::ANALYTICS_PARAM), :text => "My new program"
    end
  end

  def test_article_creation_ra
    self.expects(:program_view?).at_least(0).returns(true)
    @current_program = programs(:albers)
    RecentActivity.destroy_all
    assert_difference("RecentActivity.count", 1) do
      create_article
    end

    art = Article.last
    r1 = RecentActivity.first

    assert_match(/.*#{art.author.name}.* published #{_a_article} - .*#{art.title}/, format_recent_activity(r1, users(:f_admin)))
    assert_match(/.*#{article_path(art)}/, format_recent_activity(r1))

    activity = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::MENTORS,
      :programs => [programs(:ceg)]
    )

    act_string = format_recent_activity(activity)
  end

  def test_article_marked_as_helpful_ra
    self.expects(:program_view?).at_least(0).returns(true)
    @current_program = programs(:albers)
    art = create_article

    RecentActivity.destroy_all
    assert_difference("RecentActivity.count", 1) do
      art.mark_as_helpful!(members(:f_student))
    end

    r1 = RecentActivity.first

    assert_match(/.*#{users(:f_student).name}.* marked your #{_article} .*#{art.title}.* helpful/, format_recent_activity(r1, users(:f_mentor)))
    assert_match(/.*#{article_path(art)}/, format_recent_activity(r1))
  end

  def test_article_comment_ra
    self.expects(:program_view?).at_least(0).returns(true)
    @current_program = programs(:albers)
    art = create_article

    assert_difference("RecentActivity.count", 1) do
      @comment = art.publications.first.comments.create!(
        :user => users(:f_student), :body => "asdad"
      )
    end

    r1 = RecentActivity.last

    content = format_recent_activity(r1, users(:f_mentor))
    set_response_text(content)
    assert_match(/.*#{users(:f_student).name}.* posted a .*comment.* on your #{_article} - .*#{art.title}.*/, content)
    assert_select "a[href=\"/p/albers#{article_path(art, :src => RecentActivityHelper::ANALYTICS_PARAM, :anchor => "comment_#{@comment.id}")}\"]"
  end

  def test_group_member_addition_new_member_view
    self.expects(:program_view?).at_least(0).returns(true)
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    old_members_by_role = g.members_by_role
    mentors = ([users(:mentor_3)] + g.mentors)
    students = ([users(:student_3)] + g.students)
    assert !g.has_mentor?(users(:mentor_3))
    assert !g.has_mentee?(users(:student_3))
    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))
    assert g.has_mentee?(users(:student_3))

    assert_difference('RecentActivity.count', 2) do
      Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role)
    end

    act_string = format_recent_activity(RecentActivity.last, users(:student_3))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /Administrator added you to a/
      assert_select "a[href=\"#{group_path(g, :src => ANALYTICS_PARAM, :root => 'albers')}\"]", :text => "mentoring connection"
    end
  end

  def test_group_member_addition_existing_member_view
    self.expects(:program_view?).at_least(0).returns(true)
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    old_members_by_role = g.members_by_role
    mentors = ([users(:mentor_3)] + g.mentors)
    students = ([users(:student_3)] + g.students)
    assert !g.has_mentor?(users(:mentor_3))
    assert !g.has_mentee?(users(:student_3))
    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))
    assert g.has_mentee?(users(:student_3))

    assert_difference('RecentActivity.count', 2) do
      Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role)
    end

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /Administrator added.*#{users(:student_3).name}.*to your/
      assert_select "a[href=\"#{group_path(g, :src => ANALYTICS_PARAM, :root => 'albers')}\"]", :text => "mentoring connection"
    end
  end

  def test_group_member_update_member_addition
    self.expects(:program_view?).at_least(0).returns(true)
    g = groups(:mygroup)
    mentors = g.mentors.clone
    students = g.students.clone
    members_by_role = g.members_by_role

    mentors << users(:mentor_2)
    g.update_members(mentors, students)

    assert_difference('RecentActivity.count') do
      Group.create_ra_and_notify_members_about_member_update(g.id, members_by_role)
    end

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /Administrator added.*#{users(:mentor_2).name}.*to.*your.*mentoring connection/
      assert_select "a[href=?]", group_path(g, :src => ANALYTICS_PARAM, :root => 'albers'), :text => "mentoring connection"
    end
  end

  def test_group_member_update_member_removal
    self.expects(:program_view?).at_least(0).returns(true)
    g = groups(:mygroup)
    mentors = g.mentors.clone
    students = g.students.clone

    mentors << users(:mentor_2)
    g.update_members(mentors, students)

    mentors = mentors - [users(:mentor_2)]
    members_by_role = g.reload.members_by_role
    g.update_members(mentors, students)

    assert_difference('RecentActivity.count') do
      Group.create_ra_and_notify_members_about_member_update(g.id, members_by_role)
    end

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /Administrator removed.*#{users(:mentor_2).name}.*from.*your.*mentoring connection/
      assert_select "a[href=?]", group_path(g, :src => ANALYTICS_PARAM, :root => 'albers'), :text => "mentoring connection"
    end
  end

  def test_group_member_update_member_addition_and_removal_or_leaving
    self.expects(:program_view?).at_least(0).returns(true)
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)
    original_mentors = g.mentors.to_a.clone
    original_students = g.students.to_a.clone

    g.update_members(original_mentors, original_students + [users(:student_2)])
    members_by_role = g.reload.members_by_role
    g.update_members(original_mentors + [users(:mentor_2)], original_students)


    assert_difference('RecentActivity.count', 2) do
      Group.create_ra_and_notify_members_about_member_update(g.id, members_by_role)
    end

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /Administrator removed.*#{users(:student_2).name}.*from.*your.*mentoring connection/
      assert_select "a[href=?]", group_path(g, :src => ANALYTICS_PARAM, :root => 'albers'), :text => "mentoring connection"
    end
  end

  def test_group_reactivation_ra
    self.expects(:program_view?).at_least(0).returns(true)
    g = groups(:mygroup)
    g.terminate!(users(:f_admin), "Just like that", g.program.permitted_closure_reasons.first.id)
    assert g.closed?

    g.change_expiry_date(users(:f_admin), g.expiry_time + 1.month, "Test Reason")
    assert g.reload.active?

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /reactivated.*mentoring connection/
      assert_select "a[href=?]", member_path(members(:mkr_student), :src => RecentActivityHelper::ANALYTICS_PARAM), :text => users(:mkr_student).name
    end
  end

  def test_group_change_expiry_date_ra
    self.expects(:program_view?).at_least(0).returns(true)
    g = groups(:mygroup)
    g.change_expiry_date(users(:f_admin), g.expiry_time + 1.month, "Test Reason")
    assert g.reload.active?

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /changed the end date.*mentoring connection/
      assert_select "a[href=?]", member_path(members(:mkr_student), :src => RecentActivityHelper::ANALYTICS_PARAM), :text => users(:mkr_student).name
    end
  end

  def test_group_change_expiry_ra_non_groupee_view
    self.expects(:program_view?).at_least(0).returns(true)
    g = groups(:mygroup)

    g.change_expiry_date(users(:f_admin), g.expiry_time + 1.month, "Test Reason")
    assert g.reload.active?

    act_string = format_recent_activity(RecentActivity.last, users(:ram))
    assert act_string.nil?
  end

  def test_group_mentoring_offer_ra_mentor_view
    self.expects(:program_view?).at_least(0).returns(true)

    group = create_mentoring_offer_direct_addition
    group.program.organization.enable_feature(FeatureName::OFFER_MENTORING)

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION, ra.action_type
    act_string = format_recent_activity(RecentActivity.last, group.mentors.first)
    set_response_text(act_string)

    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /You added.*#{group.students.first.name}.*to the.*mentoring connection.*/
      assert_select "a[href=?]", member_path(group.students.first.member, :src => RecentActivityHelper::ANALYTICS_PARAM), :text => group.students.first.name
    end
  end

  def test_group_mentoring_offer_ra_mentee_view
    self.expects(:program_view?).at_least(0).returns(true)

    group = create_mentoring_offer_direct_addition
    group.program.organization.enable_feature(FeatureName::OFFER_MENTORING)

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION, ra.action_type
    act_string = format_recent_activity(RecentActivity.last, group.students.first)
    set_response_text(act_string)

    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /#{group.mentors.first.name} added you to the.*mentoring connection.*/
      assert_select "a[href=?]", member_path(group.mentors.first.member, :src => RecentActivityHelper::ANALYTICS_PARAM), :text => group.mentors.first.name
    end
  end

  def test_group_mentoring_offer_ra_admin_view
    self.expects(:program_view?).at_least(0).returns(true)

    group = create_mentoring_offer_direct_addition
    group.program.organization.enable_feature(FeatureName::OFFER_MENTORING)

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION, ra.action_type
    act_string = format_recent_activity(RecentActivity.last, users(:f_admin))
    set_response_text(act_string)

    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /#{group.mentors.first.name} added.*#{group.students.first.name}.*to the.*mentoring connection.*/
      assert_select "a[href=?]", member_path(group.mentors.first.member, :src => RecentActivityHelper::ANALYTICS_PARAM), :text => group.mentors.first.name
      assert_select "a[href=?]", member_path(group.students.first.member, :src => RecentActivityHelper::ANALYTICS_PARAM), :text => group.students.first.name
    end
  end

  def test_group_mentoring_offer_ra_non_groupee_view
    self.expects(:program_view?).at_least(0).returns(true)

    create_mentoring_offer_direct_addition

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION, ra.action_type
    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    assert_nil act_string
  end

  def test_mentoring_offer_creation_student_view
    self.expects(:program_view?).at_least(0).returns(true)

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    mentee = users(:f_student)
    mentor = users(:f_mentor)
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_CREATION, ra.action_type
    assert_equal mentor_offer, ra.ref_obj
    act_string = format_recent_activity(RecentActivity.last, mentee)
    set_response_text(act_string)

    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /You received a offer for mentoring from #{mentor.name}/
      assert_select "a[href=?]", member_path(mentor_offer.mentor.member, :src => RecentActivityHelper::ANALYTICS_PARAM), :text => /#{mentor_offer.mentor.name}/
      assert_select "a[href=?]", mentor_offers_path(:root => mentor.program.root, :src => RecentActivityHelper::ANALYTICS_PARAM), :minimum => 2
      assert_select "a[href=?]", mentor_offers_path(:root => mentor.program.root, :src => RecentActivityHelper::ANALYTICS_PARAM), :maximum => 3
    end

    program.organization.enable_feature(FeatureName::OFFER_MENTORING,false)
    act_string = format_recent_activity(RecentActivity.last, mentee)
    set_response_text(act_string)

    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /You received a offer for mentoring from #{mentor.name}/
      assert_select "a[href=?]", member_path(mentor_offer.mentor.member, :src => RecentActivityHelper::ANALYTICS_PARAM), :text => /#{mentor_offer.mentor.name}/
      assert_no_select "a[href=\"#{mentor_offers_path(:root => mentor.program.root, :src => RecentActivityHelper::ANALYTICS_PARAM)}\"]"
    end
  end

  def test_mentoring_offer_creation_mentor_view
    self.expects(:program_view?).at_least(0).returns(true)

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    mentee = users(:f_student)
    mentor = users(:f_mentor)
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)
    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_CREATION, ra.action_type
    assert_equal mentor_offer, ra.ref_obj
    act_string = format_recent_activity(RecentActivity.last, mentor)
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /You offered mentoring connection to #{mentee.name}/
    end
  end

  def test_mentoring_offer_acceptance
    self.expects(:program_view?).at_least(0).returns(true)

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    mentee = users(:f_student)
    mentor = users(:f_mentor)
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)
    mentor_offer.mark_accepted!

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_ACCEPTANCE, ra.action_type
    assert_equal mentor_offer, ra.ref_obj
    act_string = format_recent_activity(RecentActivity.last, mentor)
    set_response_text(act_string)

    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /#{mentee.name} accepted your offer for mentoring/
    end
  end

  def test_mentoring_offer_rejection
    self.expects(:program_view?).at_least(0).returns(true)

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    mentee = users(:f_student)
    mentor = users(:f_mentor)
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)
    mentor_offer.update_attribute(:status, MentorOffer::Status::REJECTED)

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_REJECTION, ra.action_type
    assert_equal mentor_offer, ra.ref_obj
    act_string = format_recent_activity(RecentActivity.last, mentor)
    set_response_text(act_string)

    assert_select "div.activity_summary" do
      assert_select "div.act_content",:text => /#{mentee.name} declined your offer for mentoring/
    end
  end

  def test_mentoring_offer_withdrawal
    self.expects(:program_view?).at_least(0).returns(true)

    program = programs(:albers)
    program.organization.enable_feature(FeatureName::OFFER_MENTORING)
    program.update_attribute(:mentor_offer_needs_acceptance, true)
    mentee = users(:f_student)
    mentor = users(:f_mentor)
    mentor_offer = create_mentor_offer(:mentor => mentor, :student => mentee)
    mentor_offer.update_attribute(:status, MentorOffer::Status::WITHDRAWN)

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::MENTOR_OFFER_WITHDRAWAL, ra.action_type
    assert_equal mentor_offer, ra.ref_obj
    act_string = format_recent_activity(RecentActivity.last)
    assert_match(/#{mentor.name}.*withdrew offer for mentoring sent to.*#{mentee.name}/, act_string)

    act_string = format_recent_activity(RecentActivity.last, mentor)
    assert_match(/You withdrew offer for mentoring sent to.*#{mentee.name}/, act_string)

    act_string = format_recent_activity(RecentActivity.last, mentee)
    assert_match(/#{mentor.name}.*withdrew offer for mentoring sent to you/, act_string)
  end

  def test_group_member_ra_links_mentor_view
    g = groups(:mygroup)
    links = group_member_ra_links(g, users(:f_mentor))
    assert_match /the mentoring connection between you and.*#{g.students.first.name}/, links
    set_response_text(links)
    assert_select "a[href=?]", member_path(g.students.first.member, :src => RecentActivityHelper::ANALYTICS_PARAM), :text => g.students.first.name
  end

  def test_group_member_ra_links_student_view
    g = groups(:mygroup)
    mentors = [users(:mentor_3)] + g.mentors
    students = g.students
    g.update_members(mentors, students)
    links = group_member_ra_links(g, g.students.first)

    assert_match /your mentoring connection with.*#{users(:f_mentor).name}.*and.*#{users(:mentor_3).name}/, links
    set_response_text(links)
    assert_select "a[href=?]", member_path(members(:f_mentor), :src => RecentActivityHelper::ANALYTICS_PARAM), :text => members(:f_mentor).name
  end

  def test_forum_created_activity
    self.expects(:program_view?).at_least(0).returns(true)
    forum = create_forum

    act_string = format_recent_activity(RecentActivity.last, users(:f_admin))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "a[href=\"#{forum_path(forum, :src => RecentActivityHelper::ANALYTICS_PARAM, :root => 'albers')}\"]", :text => forum.name
      assert_match(/Administrator created a new forum /, act_string)
    end
  end

  def test_forum_creation_ra_cannot_be_see_unless_user_is_admin_or_has_common_role
    self.expects(:program_view?).at_least(0).returns(true)
    assert_difference "RecentActivity.count" do
      forum = create_forum(:access_role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
      assert_false forum.access_role_names.include?('user')
    end
    assert_equal RecentActivityConstants::Target::ALL ,RecentActivity.last.target
    string = format_recent_activity(RecentActivity.last, users(:f_user))
    set_response_text(string)
    assert_nil string

    act_string = format_recent_activity(RecentActivity.last, users(:f_admin))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_match(/Administrator created a new forum /, act_string)
    end
  end

  def test_forum_creation_ra_cannot_be_see_if_forum_feature_is_disabled
    self.expects(:program_view?).at_least(0).returns(true)

    program = programs(:albers)
    assert program.forums_enabled?
    program.enable_feature(FeatureName::FORUMS, false)
    assert_false program.reload.forums_enabled?

    assert_difference "RecentActivity.count" do
      forum = create_forum(:access_role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
      assert_false forum.access_role_names.include?('user')
    end
    assert_equal RecentActivityConstants::Target::ALL ,RecentActivity.last.target
    string = format_recent_activity(RecentActivity.last, users(:f_user))
    set_response_text(string)
    assert_nil string

    act_string = format_recent_activity(RecentActivity.last, users(:f_admin))
    set_response_text(act_string)
    assert_nil act_string
  end

  def test_meeting_created
    self.expects(:program_view?).at_least(0).returns(true)
    meeting = create_meeting(:start_time => 20.minutes.from_now, :end_time => 50.minutes.from_now)
    act_string = format_recent_activity(RecentActivity.last, users(:f_admin))
    assert_nil act_string

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor_student))
    assert_nil act_string

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "a[href=\"#{member_path(users(:f_mentor).member, :tab => MembersController::ShowTabs::AVAILABILITY, :meeting_id => meeting.id, :root => meeting.program.root, :src => ANALYTICS_PARAM)}\"]", :text => "View meeting"
      assert_match(/created the meeting/, act_string)
    end

#   Meeting without a group
    meeting = create_meeting(:topic => "General Topic", :start_time => 40.minutes.from_now, :end_time => 60.minutes.from_now,
      :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, force_non_group_meeting: true)

    act_string = format_recent_activity(RecentActivity.last, users(:mkr_student))
    set_response_text(act_string)

    assert act_string.scan(/Visit Mentoring Connection/).empty?

    # Meeting with Customized Term
    login_as_super_user
    program = programs(:albers)
    meeting_term = program.term_for(CustomizedTerm::TermType::MEETING_TERM)
    meeting_term.update_term({:term => 'Huddle'})
    meeting = create_meeting(:start_time => 20.minutes.from_now, :end_time => 50.minutes.from_now)
    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "a[href=\"#{member_path(users(:f_mentor).member, :tab => MembersController::ShowTabs::AVAILABILITY, :meeting_id => meeting.id, :root => meeting.program.root, :src => ANALYTICS_PARAM)}\"]", :text => "View huddle"
      assert_match(/created the huddle/, act_string)
    end
  end

  def test_meeting_updated
    self.expects(:program_view?).at_least(0).returns(true)
    time = 2.days.from_now
    meeting = create_meeting(start_time: time, end_time: time + 30.minutes)
    meeting.update_attributes(:description => "Sample Meeting")
    act_string = format_recent_activity(RecentActivity.last, users(:f_admin))
    assert_nil act_string

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor_student))
    assert_nil act_string

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "a[href=\"#{member_path(users(:f_mentor).member, :tab => MembersController::ShowTabs::AVAILABILITY, :meeting_id => meeting.id, :root => meeting.program.root, :src => ANALYTICS_PARAM)}\"]", :text => "View meeting"
      assert_match(/updated the meeting/, act_string)
    end

    act_string = format_recent_activity(RecentActivity.last, users(:mkr_student))
    set_response_text(act_string)

    assert_select "div.activity_summary" do
      assert_select "a[href=\"#{member_path(users(:mkr_student).member, :tab => MembersController::ShowTabs::AVAILABILITY, :meeting_id => meeting.id, :root => meeting.program.root, :src => ANALYTICS_PARAM)}\"]", :text => "View meeting"
      assert_match(/updated the meeting/, act_string)
      assert_no_match(/Decline meeting/, act_string)
    end

#   Meeting without a group
    meeting = create_meeting(:topic => "General Topic", :group_id => nil, :start_time => time, :end_time => time + 30.minutes,
      :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, force_non_group_meeting: true)
    meeting.update_attributes(:description => "Sample Meeting")
    act_string = format_recent_activity(RecentActivity.last, users(:mkr_student))
    set_response_text(act_string)

    assert act_string.scan(/Visit Mentoring Connection/).empty?
  end

  def test_meeting_declined
    self.expects(:program_view?).at_least(0).returns(true)
    meeting = create_meeting(:start_time => 20.minutes.from_now, :end_time => 50.minutes.from_now)

    act_string = format_recent_activity(RecentActivity.last, users(:f_admin))
    assert_nil act_string

    act_string = format_recent_activity(RecentActivity.last, users(:mkr_student))
    set_response_text(act_string)
    assert_match(/created the meeting/, act_string)
    

    member_meeting = meeting.member_meetings.where(:member_id => users(:mkr_student).member).first
    member_meeting.update_attributes(:attending => false)

    act_string = format_recent_activity(RecentActivity.last, users(:mkr_student))
    set_response_text(act_string)

    assert_match(/declined the meeting/, act_string)
    assert_match(/View meeting/, act_string)

#   Meeting without a group
    meeting = create_meeting(:topic => "General Topic", :group_id => nil, :start_time => 40.minutes.from_now, :end_time => 60.minutes.from_now,
      :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, force_non_group_meeting: true)
    member_meeting = meeting.member_meetings.where(:member_id => users(:mkr_student).member).first
    member_meeting.update_attributes(:attending => MemberMeeting::ATTENDING::NO)
    act_string = format_recent_activity(RecentActivity.last, users(:mkr_student))
    set_response_text(act_string)

    assert act_string.scan(/Visit Mentoring Connection/).empty?

    act_string = format_recent_activity(RecentActivity.all[-2], users(:mkr_student))
    set_response_text(act_string)
    assert_match(/created the meeting/, act_string)
  end


  def test_meeting_accepted
    self.expects(:program_view?).at_least(0).returns(true)
    meeting = create_meeting(:start_time => 20.minutes.from_now, :end_time => 50.minutes.from_now)

    act_string = format_recent_activity(RecentActivity.last, users(:f_admin))
    assert_nil act_string
    act_string = format_recent_activity(RecentActivity.last, users(:mkr_student))
    set_response_text(act_string)
    assert_match(/created the meeting/, act_string)
    
    member_meeting = meeting.member_meetings.where(:member_id => users(:mkr_student).member).first
    member_meeting.update_attributes(:attending => MemberMeeting::ATTENDING::YES)

    act_string = format_recent_activity(RecentActivity.last, users(:mkr_student))
    set_response_text(act_string)

    assert_match(/accepted the meeting/, act_string)
    assert_match(/View meeting/, act_string)
  end

  def test_qa_question_created
    self.expects(:program_view?).at_least(0).returns(true)
    @current_program = programs(:albers)
    qa_question = nil
    assert_difference 'RecentActivity.count',1 do
      qa_question = create_qa_question(:user => users(:f_admin), :program => programs(:albers), :summary => "hello", :description => "how are you?")
    end

    act_string = format_recent_activity(RecentActivity.last, users(:f_admin))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "a[href=\"#{qa_question_path(qa_question, :src => RecentActivityHelper::ANALYTICS_PARAM, :root => 'albers')}\"]", :text => qa_question.summary
      assert_match(/You asked a question /, act_string)
    end

    act_string = format_recent_activity(RecentActivity.last, users(:f_student))
    set_response_text(act_string)
    assert_select "div.activity_summary" do
      assert_select "a[href=\"#{qa_question_path(qa_question, :src => RecentActivityHelper::ANALYTICS_PARAM, :root => 'albers')}\"]", :text => qa_question.summary
      assert_match(/.*Freakin Admin.* asked a question /, act_string)
    end
  end

  def test_qa_answer_created
    self.expects(:program_view?).at_least(0).returns(true)
    @current_program = programs(:albers)
    groups(:group_pbe).destroy

    qa_answer = nil
    qa_question = create_qa_question(:user => users(:f_mentor))
    assert_difference 'RecentActivity.count',1 do
      qa_answer = create_qa_answer(:qa_question => qa_question, :user => users(:f_admin), :content => 'Answer for RA')
    end

    assert_equal qa_question.user ,users(:f_mentor)
    qa_question.send(:mark_follow!, users(:f_mentor))

    act_string = format_recent_activity(RecentActivity.last, users(:f_mentor))
    # TODO:: Fix this test, failing when full tests are run, deprioritizing as it is an RA test
    # assert_match /#{qa_question_path(qa_question, :src => RecentActivityHelper::ANALYTICS_PARAM, :root => 'albers')}/, act_string
    assert_match(/.*Freakin Admin.* posted an answer for your question/, act_string)
    assert_match /#{qa_question.summary}/, act_string

    follower = users(:f_student)
    current_user_is follower
    current_program_is :albers
    qa_question.toggle_follow!(follower)
    assert qa_question.reload.follow?(follower)

    act_string = format_recent_activity(RecentActivity.last, follower)
    # TODO:: Fix this test, failing when full tests are run, deprioritizing as it is an RA test
    # assert_match /#{qa_question_path(qa_question, :src => RecentActivityHelper::ANALYTICS_PARAM, :root => 'albers')}/, act_string
    assert_match(/.*Freakin Admin.* posted an answer for the question/, act_string)
    assert_match /#{qa_question.summary}/, act_string
  end

  def test_notify_airbrake_if_format_recent_activity_exception
    Airbrake.expects(:notify).times(1)
    assert_nothing_raised do
      format_recent_activity(nil)
    end
  end

  def test_view_user_is_admin_or_has_common_role
    user_1 = users(:f_mentor)
    user_2 = users(:f_admin)

    assert view_user_is_admin_or_has_common_role(user_1, [RoleConstants::MENTOR_NAME])
    assert view_user_is_admin_or_has_common_role(user_1, [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert view_user_is_admin_or_has_common_role(user_1, [], for_all: true)
    assert_false view_user_is_admin_or_has_common_role(user_1, [RoleConstants::STUDENT_NAME])
    assert_false view_user_is_admin_or_has_common_role(user_1, [])

    assert view_user_is_admin_or_has_common_role(user_2, [RoleConstants::MENTOR_NAME])
    assert view_user_is_admin_or_has_common_role(user_2, [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    assert view_user_is_admin_or_has_common_role(user_2, [], for_all: true)
    assert view_user_is_admin_or_has_common_role(user_2, [RoleConstants::STUDENT_NAME])
    assert view_user_is_admin_or_has_common_role(user_2, [])
  end

  def test_get_text_based_on_grammatical_person
    action_type = RecentActivityConstants::Type::MENTOR_REQUEST_CREATION
    mentor = users(:f_mentor)
    student = users(:f_student)
    admin = users(:f_admin)

    # Case 1: RA on mentor's track level feed for mentor request creation
    @current_user = mentor
    ra_text = get_text_based_on_grammatical_person(action_type, student, mentor, default_key: "mentor_request_creation").translate
    assert ra_text.ends_with?("you")
    assert_false ra_text.starts_with?("You")

    # Case 2: RA on mentee's track level feed for mentor request creation
    @current_user = student
    ra_text = get_text_based_on_grammatical_person(action_type, student, mentor, default_key: "mentor_request_creation").translate
    assert_false ra_text.ends_with?("you")
    assert ra_text.starts_with?("You")

    # Case 3: RA on admin's track level feed for mentor request creation
    @current_user = admin
    ra_text = get_text_based_on_grammatical_person(action_type, student, mentor, default_key: "mentor_request_creation").translate
    assert_false ra_text.ends_with?("you")
    assert_false ra_text.starts_with?("You")

    # Case 4: RA on mentor's org level feed for mentor request creation
    self.expects(:organization_view?).at_least(0).returns(true)
    @current_user = nil
    self.expects(:wob_member).at_least(0).returns(mentor.member)
    ra_text = get_text_based_on_grammatical_person(action_type, student.member, mentor, default_key: "mentor_request_creation").translate
    assert ra_text.ends_with?("you")
    assert_false ra_text.starts_with?("You")

    # Case 5: RA on mentee's org level feed for mentor request creation
    self.expects(:wob_member).at_least(0).returns(student.member)
    ra_text = get_text_based_on_grammatical_person(action_type, student.member, mentor, default_key: "mentor_request_creation").translate
    assert_false ra_text.ends_with?("you")
    assert ra_text.starts_with?("You")

    # Case 6: When options[:default_key] is not passed, key prefixed with gp_ is returned
    self.expects(:wob_member).at_least(0).returns(admin.member)
    assert_equal "feature.recent_activity.content.gp_mentor_request_creation_html", get_text_based_on_grammatical_person(action_type, student.member, mentor)

    # Only subject based RA - is_object_present: false is passed
    # Case 7: RA on mentor's track level feed for mentor joining the program
    action_type = RecentActivityConstants::Type::MENTOR_JOIN_PROGRAM
    @current_user = mentor
    self.expects(:wob_member).at_least(0).returns(mentor.member)
    ra_text = get_text_based_on_grammatical_person(action_type, mentor, nil, default_key: "mentor_join_program", is_object_present: false).translate
    assert ra_text.starts_with?("You")

    # Case 8: RA on mentor's org level feed for mentor joining the program
    self.expects(:wob_member).at_least(0).returns(mentor.member)
    ra_text = get_text_based_on_grammatical_person(action_type, mentor.member, nil, default_key: "mentor_join_program", is_object_present: false).translate
    assert ra_text.starts_with?("You")

    # Case 9: RA on admin's track level feed for mentor joining the program
    self.expects(:wob_member).at_least(0).returns(admin.member)
    @current_user = admin
    ra_text = get_text_based_on_grammatical_person(action_type, mentor, nil, default_key: "mentor_join_program", is_object_present: false).translate
    assert_false ra_text.starts_with?("You")

    # Case 10: RA on track level admin's org level feed for mentor joining the program
    admin.member.update_attributes!(admin: false)
    self.expects(:wob_member).at_least(0).returns(admin.member.reload)
    @current_user = nil
    ra_text = get_text_based_on_grammatical_person(action_type, mentor.member, nil, default_key: "mentor_join_program", is_object_present: false).translate
    assert_false ra_text.starts_with?("You")
  end

  def test_mentor_request_related_recent_activity_uses_grammatical_person
    self.expects(:program_view?).at_least(0).returns(true)
    mentor = users(:f_mentor)
    student = users(:f_student)
    mentor_req = create_mentor_request

    # Case 1: Mentee initiated actions
    recent_activity = RecentActivity.create!(
      programs: [programs(:albers)],
      member: student.member,
      for: mentor.member,
      ref_obj: mentor_req,
      action_type: RecentActivityConstants::Type::MENTOR_REQUEST_CREATION,
      target: RecentActivityConstants::Target::USER)

    self.expects(:get_text_based_on_grammatical_person).with(RecentActivityConstants::Type::MENTOR_REQUEST_CREATION, student, mentor, default_key: "mentor_request_creation").once.returns("display_string.ok")
    get_ra_object(recent_activity)

    recent_activity.update_attributes!(action_type: RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL)
    self.expects(:get_text_based_on_grammatical_person).with(RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL, student, mentor, default_key: "mentor_request_withdrawal_v1").once.returns("display_string.ok")
    get_ra_object(recent_activity)

    # Case 1: Mentor initiated actions
    recent_activity.update_attributes!(
      member: mentor.member,
      for: student.member,
      action_type: RecentActivityConstants::Type::MENTOR_REQUEST_ACCEPTANCE)
    self.expects(:get_text_based_on_grammatical_person).with(RecentActivityConstants::Type::MENTOR_REQUEST_ACCEPTANCE, mentor, student, default_key: "mentor_request_acceptance_v1").once.returns("display_string.ok")
    get_ra_object(recent_activity)

    recent_activity.update_attributes!(action_type: RecentActivityConstants::Type::MENTOR_REQUEST_REJECTION)
    self.expects(:get_text_based_on_grammatical_person).with(RecentActivityConstants::Type::MENTOR_REQUEST_REJECTION, mentor, student, default_key: "mentor_request_rejection_v1").once.returns("display_string.ok")
    get_ra_object(recent_activity)
  end

  private

  def _a_mentor
    "a mentor"
  end

  def _a_admin
    "an administrator"
  end

  def _Admin
    "Administrator"
  end

  def _admin
    "administrator"
  end

  def _mentoring_connection
    "mentoring connection"
  end

  def _mentoring_connections
    "mentoring connections"
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def _Mentoring_Connections
    "Mentoring Connections"
  end

  def _a_article
    "an article"
  end

  def _article
    "article"
  end

  def _Article
    "Article"
  end

  def _articles
    "articles"
  end

  def _Articles
    "Articles"
  end

  def _program
    "program"
  end

  def _meeting
    "meeting"
  end

  def _meetings
    "meetings"
  end

  def _Meeting
    "Meeting"
  end

  def _Meetings
    "Meetings"
  end

end
