require_relative './../test_helper.rb'

class JobLogTest < ActiveSupport::TestCase
  def test_associations
    user = users(:f_mentor)
    announcement = create_announcement
    job_log = create_job_log(object: announcement, user: user)
    assert_equal user, job_log.ref_obj
    assert_equal announcement, job_log.loggable_object
  end

  def test_validations
    job_log = JobLog.new

    job_log.job_uuid = "1"

    assert_false job_log.valid?
    assert_equal ["Ref obj can't be blank"], job_log.errors.full_messages
    job_log.ref_obj_id = users(:f_mentor).id
    job_log.ref_obj_type = User.name
    assert job_log.valid?

    job_log.job_uuid = nil
    job_log.ref_obj_id = nil
    job_log.ref_obj_type = nil
    assert_false job_log.valid?

    assert_equal ["can't be blank"], job_log.errors[:action_type]
    assert_equal ["can't be blank"], job_log.errors[:loggable_object_id]
    assert_equal ["can't be blank"], job_log.errors[:loggable_object_type]
    assert_equal ["can't be blank"], job_log.errors[:job_uuid]
    assert_equal ["can't be blank", "can't be blank"], job_log.errors[:ref_obj_id]
    assert_equal ["can't be blank"], job_log.errors[:ref_obj_type]

    announcement = create_announcement

    assert_nothing_raised do
      create_job_log(object: announcement)
      job_log = create_job_log(object: announcement, action_type: RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE)
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :ref_obj_id do
      job_log.update_attributes!(action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION)
    end

    assert_nothing_raised do
      create_job_log(object: announcement, action_type: RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, version_id: 2)
    end
  end

  def test_compute_with_historical_data
    announcement = create_announcement
    user1 = users(:f_mentor)
    user2 = users(:mkr_student)

    Airbrake.expects(:notify).never
    User.any_instance.expects(:send_email).times(2)
    assert_difference "JobLog.count", 2 do
      JobLog.compute_with_historical_data([user1, user2], announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version) do |user|
        user.send_email(announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, initiator: announcement.admin)
      end
    end

    job_logs = JobLog.last(2)
    assert_equal user1, job_logs.first.ref_obj
    assert_equal user2, job_logs.second.ref_obj
    assert_equal [announcement, announcement], job_logs.collect(&:loggable_object)
    assert_equal [RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION], job_logs.collect(&:action_type)
    assert_equal [announcement.version, announcement.version], job_logs.collect(&:version_id)

    Airbrake.expects(:notify).never
    User.any_instance.expects(:send_email).never
    assert_no_difference "JobLog.count" do
      JobLog.compute_with_historical_data([user1, user2], announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version) do |user|
        user.send_email(announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, initiator: announcement.admin)
      end
    end

    Airbrake.expects(:notify).never
    User.any_instance.expects(:send_email).times(2)
    assert_difference "JobLog.count", 2 do
      JobLog.compute_with_historical_data([user1, user2], announcement, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, announcement.version) do |user|
        user.send_email(announcement, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, initiator: announcement.admin)
      end
    end

    job_logs = JobLog.last(2)
    assert_equal user1, job_logs.first.ref_obj
    assert_equal user2, job_logs.second.ref_obj
    assert_equal [announcement, announcement], job_logs.collect(&:loggable_object)
    assert_equal [RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE], job_logs.collect(&:action_type)
    assert_equal [announcement.version, announcement.version], job_logs.collect(&:version_id)

    Airbrake.expects(:notify).never
    User.any_instance.expects(:send_email).never
    assert_no_difference "JobLog.count" do
      JobLog.compute_with_historical_data([user1, user2], announcement, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, announcement.version) do |user|
        user.send_email(announcement, RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE, initiator: announcement.admin)
      end
    end
  end

  def test_compute_with_historical_data_raises_exception
    user1 = users(:f_mentor)
    user2 = users(:mkr_student)
    announcement = create_announcement

    Airbrake.expects(:notify).times(1)
    assert_difference "JobLog.count" do
      JobLog.compute_with_historical_data([user1, user2], announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version) do |user|
        user.id == user2.id ? user.send_email(announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, initiator: announcement.admin) : raise("Sample Error")
      end
    end

    Airbrake.expects(:notify).times(1)
    assert_no_difference "JobLog.count" do
      JobLog.compute_with_historical_data([user1, user2], nil, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version, klass_name: announcement.class.name, klass_id: announcement.id) do |user|
        user.id == user2.id ? user.send_email(announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, initator: announcement.admin) : raise("Sample Error")
      end
    end
  end

  def test_raise_if_no_block_given
    announcement = create_announcement
    assert_raise RuntimeError do
      JobLog.compute_with_historical_data([users(:f_mentor)], announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version)
    end
  end

  def test_compute_with_historical_data_with_options
    user1 = users(:f_mentor)
    user2 = users(:mkr_student)
    announcement = create_announcement
    users_list = [user1, user2]
    users_list.map{|user| user.update_attributes!(program_notification_setting: UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE)}
    announcement.program.mailer_template_enable_or_disable(AnnouncementNotification, true)

    assert_difference "JobLog.count", 2 do
      assert_emails 2 do
        JobLog.compute_with_historical_data(users_list, nil, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version, klass_name: announcement.class.name, klass_id: announcement.id) do |user|
          user.send_email(announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, initiator: announcement.admin)
        end
      end
    end
    job_logs = JobLog.all.last(2)
    assert_equal ["Announcement", "Announcement"], job_logs.collect(&:loggable_object_type)
    assert_equal [announcement.id, announcement.id], job_logs.collect(&:loggable_object_id)
    assert_equal [user1.id, user2.id], job_logs.collect(&:ref_obj_id)


    assert_no_difference "JobLog.count" do
      assert_no_emails do
        JobLog.compute_with_historical_data(users_list, announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version) do |user|
          user.send_email(announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, initiator: announcement.admin)
        end
      end
    end

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        JobLog.compute_with_historical_data(users_list, nil, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, announcement.version, klass_name: announcement.class.name, klass_id: announcement.id) do |user|
          user.send_email(announcement, RecentActivityConstants::Type::ANNOUNCEMENT_CREATION, initiator: announcement.admin)
        end
      end
    end
  end

  def test_compute_with_uuid
    program = programs(:albers)
    # Making sure users is an ActiveRecord::Collection object
    users = program.users.where(id: [users(:f_admin).id, users(:f_student).id, users(:f_mentor).id, users(:rahim).id])

    assert_raise RuntimeError do
      assert_difference "JobLog.count", 2 do
        JobLog.compute_with_uuid(users, "15") do |user|
          raise "Test Exception" if user.id == users(:f_mentor).id
        end
      end
    end

    assert_raise RuntimeError do
      assert_no_difference "JobLog.count" do
        JobLog.compute_with_uuid(users, "15") do |user|
          raise "Test Exception" if user.id == users(:f_mentor).id
        end
      end
    end

    assert_difference "JobLog.count", 2 do
      JobLog.compute_with_uuid(users, "15") do |user|
        # Do Something
      end
    end
  end

  def test_compute_with_uuid_job_id_nil_scenario
    program = programs(:albers)
    # Making sure users is an ActiveRecord::Collection object
    users = program.users.where(id: [users(:f_admin).id, users(:f_student).id, users(:f_mentor).id, users(:rahim).id])

    iterator = 0
    assert_raise RuntimeError do
      assert_no_difference "JobLog.count" do
        JobLog.compute_with_uuid(users, nil) do |user|
          raise "Test Exception" if user.id == users(:f_mentor).id
          iterator += 1
        end
      end
    end
    assert_equal 2, iterator

    iterator = 0
    assert_raise RuntimeError do
      assert_no_difference "JobLog.count" do
        JobLog.compute_with_uuid(users, nil) do |user|
          raise "Test Exception" if user.id == users(:f_mentor).id
          iterator += 1
        end
      end
    end
    assert_equal 2, iterator

    iterator = 0
    assert_no_difference "JobLog.count" do
      JobLog.compute_with_uuid(users, nil) do |user|
        iterator += 1
      end
    end
    assert_equal 4, iterator
  end
end