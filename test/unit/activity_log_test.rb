require_relative './../test_helper.rb'

class ActivityLogTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
  def test_should_log
    mentor_u = users(:f_mentor)

    assert_difference 'ActivityLog.program_visits.count' do
      ActivityLog.log_activity(mentor_u, ActivityLog::Activity::PROGRAM_VISIT)
    end

    assert_difference 'ActivityLog.community_visits.count' do
      ActivityLog.log_activity(mentor_u, ActivityLog::Activity::RESOURCE_VISIT)
    end

    assert_difference 'ActivityLog.community_visits.count' do
      ActivityLog.log_activity(mentor_u, ActivityLog::Activity::FORUM_VISIT)
    end

    assert_difference 'ActivityLog.community_visits.count' do
      ActivityLog.log_activity(mentor_u, ActivityLog::Activity::ARTICLE_VISIT)
    end

    assert_difference 'ActivityLog.community_visits.count' do
      ActivityLog.log_activity(mentor_u, ActivityLog::Activity::QA_VISIT)
    end

    assert_difference 'ActivityLog.mentoring_visits.count' do
      ActivityLog.log_mentoring_visit(mentor_u)
    end

    student_u = users(:f_student)

    assert_difference 'ActivityLog.program_visits.count' do
      ActivityLog.log_activity(student_u, ActivityLog::Activity::PROGRAM_VISIT)
    end
  end

  def test_should_not_log
    # admin user scenario
    admin_u = users(:f_admin)
    assert_no_difference 'ActivityLog.program_visits.count' do
      ActivityLog.log_activity(admin_u, ActivityLog::Activity::PROGRAM_VISIT)
    end

    # other users scenario
    mentor_u = users(:f_mentor)
    e = assert_raise(ActiveRecord::RecordInvalid) do
      ActivityLog.log_activity(mentor_u, -1)
    end
    assert_match(/Activity is not included in the list/, e.message)

    ActivityLog.log_activity(mentor_u, ActivityLog::Activity::PROGRAM_VISIT)

    assert_no_difference 'ActivityLog.program_visits.count' do
      ActivityLog.log_activity(mentor_u, ActivityLog::Activity::PROGRAM_VISIT)
    end

    assert_no_difference 'ActivityLog.program_visits.count' do
      ActivityLog.log_activity(nil, ActivityLog::Activity::PROGRAM_VISIT)
    end
  end

  def test_timezone
    assert_difference 'ActivityLog.count' do
      ActivityLog.log_activity(users(:f_mentor), ActivityLog::Activity::PROGRAM_VISIT)
    end

    Time.zone = "Asia/Kolkata"
    assert_no_difference 'ActivityLog.count' do
      ActivityLog.log_activity(users(:f_mentor), ActivityLog::Activity::PROGRAM_VISIT)
    end

    Time.zone = "America/Los_Angeles"
    assert_no_difference 'ActivityLog.count' do
      ActivityLog.log_activity(users(:f_mentor), ActivityLog::Activity::PROGRAM_VISIT)
    end
    
    Time.zone = "Asia/Tokyo"
    assert_no_difference 'ActivityLog.count' do
      ActivityLog.log_activity(users(:f_mentor), ActivityLog::Activity::PROGRAM_VISIT)
    end
  end

  def test_observers_reindex_es
    mentor_u = users(:f_mentor)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).never # Dont call if the activitiy type is not program_visit

    ActivityLog.log_activity(mentor_u, ActivityLog::Activity::QA_VISIT)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(2).with(User, [mentor_u.id])
    ActivityLog.log_activity(mentor_u, ActivityLog::Activity::PROGRAM_VISIT)

    ActivityLog.last.destroy
  end

end
