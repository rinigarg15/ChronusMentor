require_relative './../../../test_helper'

class DigestV2Utils::TriggerTest < ActiveSupport::TestCase
  def setup
    super
    @trigger = DigestV2Utils::Trigger.new
    @trigger.instance_eval "def delay(*args); self; end"
  end

  def test_selected_user_ids_grouped_by_program
    selected_time_zone = "Asia/Kolkata"
    hsh = @trigger.send(:selected_user_ids_grouped_by_program, [selected_time_zone])
    assert_equal_hash({}, hsh)
    user = users(:f_mentor)
    user.member.update_attribute(:time_zone, selected_time_zone)
    hsh = @trigger.send(:selected_user_ids_grouped_by_program, [selected_time_zone])
    assert_equal_hash(user.member.users.map{|u| [u.program_id, [u.id]]}.to_h, hsh)
  end

  def test_check_time_limit_exceeded
    time_now = Time.utc(2011,7,7,0,0,0)
    Timecop.freeze(time_now) do
      @trigger.send(:check_time_limit_exceeded, "Etc/GMT-6")
      @trigger.send(:check_time_limit_exceeded, "Etc/GMT-9")
      Airbrake.expects(:notify).once.returns(true)
      @trigger.send(:check_time_limit_exceeded, "Etc/GMT-11")
    end
  end

  def test_get_valid_time_zones_at_this_time
    Timecop.freeze(Time.utc(2011,7,7,0,0,0)) do
      assert_equal ["Antarctica/Davis", "Asia/Bangkok", "Asia/Barnaul", "Asia/Ho_Chi_Minh", "Asia/Hovd", "Asia/Jakarta", "Asia/Novokuznetsk", "Asia/Novosibirsk", "Asia/Omsk", "Asia/Phnom_Penh", "Asia/Pontianak", "Asia/Tomsk", "Asia/Vientiane", "Etc/GMT-7", "Indian/Christmas"], @trigger.send(:get_valid_time_zones_at_this_time)
    end
    Timecop.freeze(Time.utc(2011,7,7,1,30,0)) do
      assert_equal ["Asia/Colombo", "Asia/Kathmandu", "Asia/Kolkata"], @trigger.send(:get_valid_time_zones_at_this_time)
    end
  end

  def test_send_digest_v2_for_user
    Timecop.freeze do
      user = users(:f_mentor)
      program = user.program
      previous_month = Time.current.prev_month
      time_range = ((previous_month.beginning_of_month)..(previous_month.end_of_month))
      article = program.articles.first
      article.update_attribute(:created_at, Time.current.prev_month.end_of_month - 5.days)
      options = {most_viewed_content_details: program.get_most_viewed_community_contents(time_range, DigestV2Utils::Trigger::MOST_VIEWED_CONTENT_COUNT).map{|hsh| {klass: hsh[:object].class.name, id: hsh[:object].id, role_id: hsh[:role_id]}}}
      user.group_notification_setting = UserConstants::DigestV2Setting::GroupUpdates::WEEKLY
      user.last_group_update_sent_time = 2.weeks.ago
      user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
      user.last_program_update_sent_time = 2.weeks.ago
      user.save
      user.send_email(article, RecentActivityConstants::Type::ARTICLE_CREATION)
      membership = user.connection_memberships[0]
      membership.send_email(user, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE, nil, nil, {})
      assert_equal 1, user.pending_notifications.size
      assert_equal 1, membership.pending_notifications.size
      assert_emails(1) do
        @trigger.send(:send_digest_v2_for_user, user.id, options)
      end
      assert_equal [], user.pending_notifications
      assert_equal [], membership.pending_notifications
      assert_equal Time.now.to_i, user.reload.last_group_update_sent_time.to_i
      assert_equal Time.now.to_i, user.reload.last_program_update_sent_time.to_i
    end
  end

  def test_send_digest_v2_for_program
    Timecop.freeze do
      user = users(:f_mentor)
      program = user.program
      user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
      user.last_program_update_sent_time = 2.weeks.ago
      user.save
      @trigger.expects(:delay).twice.returns(@trigger)
      @trigger.class_eval "public :send_digest_v2_for_user"
      @trigger.expects(:send_digest_v2_for_user).once.returns(true)
      @trigger.class_eval "public :check_time_limit_exceeded"
      @trigger.expects(:check_time_limit_exceeded).once
      @trigger.send(:send_digest_v2_for_program, program.id, [user.id, users(:f_student).id], "", true)
    end
  end

  def test_start
    user = users(:f_mentor)
    program = user.program
    @trigger.expects(:get_valid_time_zones_at_this_time).once.returns("Asia/Kolkata")
    @trigger.expects(:selected_user_ids_grouped_by_program).once.returns({program.id => [user.id]})
    @trigger.class_eval "public :send_digest_v2_for_program"
    @trigger.expects(:send_digest_v2_for_program).once
    @trigger.start
  end
end