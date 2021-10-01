require_relative "./../test_helper.rb"

class DigestV2Test < ActiveSupport::TestCase
  def setup
    super
    @digest_v2 = DigestV2.send(:new)
  end

  def test_digest_mail_needed_after_analyzing_content
    @digest_v2.instance_variable_set(:"@total_activity_count", 0)
    assert_false @digest_v2.send(:digest_mail_needed_after_analyzing_content?)
    @digest_v2.instance_variable_set(:"@total_activity_count", 1)
    assert @digest_v2.send(:digest_mail_needed_after_analyzing_content?)
  end

  def test_digest_v2
    user = users(:f_mentor)
    member = user.member
    program = user.program
    previous_month = Time.current.prev_month
    time_range = ((previous_month.beginning_of_month)..(previous_month.end_of_month))
    article = program.articles.first
    article.update_attribute(:created_at, Time.current.prev_month.end_of_month - 5.days)
    options = {most_viewed_content_details: program.get_most_viewed_community_contents(time_range, DigestV2Utils::Trigger::MOST_VIEWED_CONTENT_COUNT).map{|hsh| {klass: hsh[:object].class.name, id: hsh[:object].id, role_id: hsh[:role_id]}}}
    user.group_notification_setting = UserConstants::DigestV2Setting::GroupUpdates::WEEKLY
    user.last_group_update_sent_time = 1.year.ago
    user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
    user.last_program_update_sent_time = 1.year.ago
    user.save
    ProfileView.create!(user: user, viewed_by: users(:f_student))
    user.send_email(article, RecentActivityConstants::Type::ARTICLE_CREATION)
    membership = user.connection_memberships[0]
    membership.send_email(user, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE, nil, nil, {})
    assert_equal 1, user.pending_notifications.size
    assert_equal 1, membership.pending_notifications.size
    email = @digest_v2.digest_v2(user, options)
    assert_match /Here's a snapshot of your updates!/, get_text_part_from(email)

    assert_equal user, @digest_v2.instance_variable_get(:"@user")
    assert_equal member, @digest_v2.instance_variable_get(:"@member")
    total_activity_count = 3 # 4 => 3, discounting the profile view which is temporarily disabled
    assert_equal total_activity_count, @digest_v2.instance_variable_get(:"@total_activity_count")

    assert_equal [{:card_content=>"India state economy", :call_to_action_url=>[:article_url, article], :authors=>["Freakin Admin"], :icon_src=>"https://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/icomoon-free_2014-12-23_blog_30_0_717073_none.png", :card_footer=>"by Freakin Admin", :card_heading=>"Posted an article", :subject=>"New article 'India state economy'"}], @digest_v2.send(:get_card_details)
    assert_equal_hash({RecentActivityConstants::Type::ARTICLE_CREATION=>user.pending_notifications}, @digest_v2.instance_variable_get(:"@user_pending_notifications"))
    assert_equal 1, @digest_v2.instance_variable_get(:"@popular_content_card_details").size
    popular_content_card_detail = @digest_v2.instance_variable_get(:"@popular_content_card_details")[0]
    assert_equal article.title, popular_content_card_detail[:card_content]
    assert_equal :article_url, popular_content_card_detail[:call_to_action_url][0]
    assert_equal_hash({:card_footer=>"by Freakin Admin", :card_heading=>"Posted a article", :subject=>"Popular Article - 'India state economy'"}, popular_content_card_detail.pick(:card_footer, :card_heading, :subject))
    # assert_equal [users(:f_student)], @digest_v2.instance_variable_get(:"@viewed_by_users") # temporarily disabled
    assert_equal [membership], @digest_v2.instance_variable_get(:"@selected_connection_memberships")
    assert_equal_hash({membership.id => {upcoming_tasks: [], pending_tasks: [], pending_notifications: membership.pending_notifications}}, @digest_v2.instance_variable_get(:"@selected_connection_membership_details"))

    assert_equal "Popular Discussion - 'abcd'", @digest_v2.send(:get_popular_content_subject, DigestV2::PopularContentType::TOPIC, {card_content: 'abcd'})
    assert_equal 12, @digest_v2.instance_variable_get(:"@received_requests_count")
    assert_equal [:meeting_requests_url, {:subdomain=>"primary", :domain=>DEFAULT_DOMAIN_NAME, :root=>"albers", :src=>:digest_v2, :src1=>:important_next_steps}], @digest_v2.instance_variable_get(:"@received_requests_call_to_action")
    assert_equal 4, @digest_v2.instance_variable_get(:"@unread_inbox_messages_count")
    assert_equal [:messages_url, {:organization_level=>true, :"search_filters[status][unread]"=>0, :tab=>0, :subdomain=>"primary", :domain=>DEFAULT_DOMAIN_NAME, :root=>"albers", :src=>:digest_v2, :src1=>:important_next_steps}], @digest_v2.instance_variable_get(:"@unread_inbox_messages_call_to_action")
    assert_equal 0, @digest_v2.instance_variable_get(:"@upcoming_not_responded_meetings_count")

    assert_equal "subject and #{total_activity_count-1} more updates!", @digest_v2.send(:update_subject_with_n_more_updates!, "subject") # 3 => 2 
    assert_equal "subject and 1 more update!", @digest_v2.send(:update_subject_with_n_more_updates!, "subject", 1)
    assert_equal "subject", @digest_v2.send(:update_subject_with_n_more_updates!, "subject", 0)

    assert_equal "a, b and 1 more", @digest_v2.send(:ary_to_sentence_with_x_more, ['a', 'b', 'c'], 2)
    assert_equal "a, b and c", @digest_v2.send(:ary_to_sentence_with_x_more, ['a', 'b', 'c'], 5)
    assert_equal "a and 2 more", @digest_v2.send(:ary_to_sentence_with_x_more, ['a', 'b', 'c'], 1)
  end
end