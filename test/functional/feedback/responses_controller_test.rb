require_relative './../../test_helper.rb'

class Feedback::ResponsesControllerTest < ActionController::TestCase

  def setup
    super
    @program = programs(:albers)
    @program.enable_feature(FeatureName::COACH_RATING, true)
    @group = groups(:mygroup)
    @mentee = @group.students.first
    @mentor = @group.mentors.first
    @feedback_form = @program.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
  end

  def test_new
    current_user_is :mkr_student
    get :new, xhr: true, params: { :group_id => @group.id, :recipient_id => @mentor.id}
    feedback_questions = @feedback_form.questions

    assert_equal feedback_questions, assigns(:feedback_questions)
    assert_equal assigns(:group), @group
    assert_equal assigns(:recipient), @mentor
    assert assigns(:feedback_response).new_record?
  end

  def test_create
    current_user_is :mkr_student
    assert_difference 'UserStat.count', 1 do
      assert_difference 'Feedback::Answer.count', 1 do
        assert_difference 'Feedback::Response.count', 1 do
          assert_emails programs(:albers).admin_users.active.size do
            post :create, xhr: true, params: { :feedback_answers => {@feedback_form.questions.first.id => "good"}, :feedback_response => {:group_id => @group.id, :recipient_id => @mentor.id}, :score => 4}
          end
        end
      end
    end

    assert_equal assigns(:group), @group
    assert_equal assigns(:recipient), @mentor

    email = ActionMailer::Base.deliveries.last
    assert_equal email.subject, "Good unique has been rated by mkr_student"
    assert email.to.include?(users(:ram).email)

    email_html = get_html_part_from(email)
    assert_match /Rating: 4.0/, email_html
    assert_match /Comments: good/, email_html

    user_stat = UserStat.last
    assert_equal user_stat.user_id, @mentor.id
    assert_equal user_stat.rating_count, 1
    assert_equal user_stat.average_rating, 4
  end

  def test_new_with_feature_disabled
    programs(:albers).enable_feature(FeatureName::COACH_RATING, false)
    current_user_is :mkr_student
    assert_permission_denied do
      get :new, xhr: true, params: { :group_id => @group.id, :recipient_id => @mentor.id}
    end
  end

  def test_create_with_feature_disabled
    programs(:albers).enable_feature(FeatureName::COACH_RATING, false)
    current_user_is :mkr_student

    assert_no_difference 'UserStat.count' do
      assert_no_difference 'Feedback::Answer.count' do
        assert_no_difference 'Feedback::Response.count' do
          assert_no_emails do
            assert_permission_denied do
              post :create, xhr: true, params: { :feedback_answers => {@feedback_form.questions.first.id => "good"}, :feedback_response => {:group_id => @group.id, :recipient_id => @mentor.id}, :score => 4}
            end
          end
        end
      end
    end
  end

  def test_create_with_unpublished_group
    current_user_is :student_1
    drafted_group = groups(:drafted_group_1)
    mentee = drafted_group.students.first
    mentor = drafted_group.mentors.first

    assert_no_difference 'UserStat.count' do
      assert_no_difference 'Feedback::Answer.count' do
        assert_no_difference 'Feedback::Response.count' do
          assert_no_emails do
            assert_raise ActiveRecord::RecordNotFound do
              post :create, xhr: true, params: { :feedback_answers => {@feedback_form.questions.first.id => "good"}, :feedback_response => {:group_id => drafted_group.id, :recipient_id => mentor.id}, :score => 4}
            end
          end
        end
      end
    end
  end

  def test_create_with_mentor_from_different_group
    current_user_is :mkr_student

    assert_false @group.mentors.include?(users(:mentor_1))

    assert_no_difference 'UserStat.count' do
      assert_no_difference 'Feedback::Answer.count' do
        assert_no_difference 'Feedback::Response.count' do
          assert_no_emails do
            assert_raise ActiveRecord::RecordNotFound do
              post :create, xhr: true, params: { :feedback_answers => {@feedback_form.questions.first.id => "good"}, :feedback_response => {:group_id => @group.id, :recipient_id => users(:mentor_1).id}, :score => 4}
            end
          end
        end
      end
    end
  end

  def test_create_with_mentee_from_different_group
    current_user_is :f_student

    assert_false @group.students.include?(users(:f_student))

    assert_no_difference 'UserStat.count' do
      assert_no_difference 'Feedback::Answer.count' do
        assert_no_difference 'Feedback::Response.count' do
          assert_no_emails do
            assert_raise ActiveRecord::RecordNotFound do
              post :create, xhr: true, params: { :feedback_answers => {@feedback_form.questions.first.id => "good"}, :feedback_response => {:group_id => @group.id, :recipient_id => @mentor.id}, :score => 4}
            end
          end
        end
      end
    end
  end

end