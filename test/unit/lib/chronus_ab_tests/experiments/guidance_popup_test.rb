require_relative './../../../../test_helper.rb'

class Experiments::GuidancePopupTest < ActionView::TestCase
  def test_title
    assert_equal "SMP Guidance Popup V2", Experiments::GuidancePopup.title
  end

  def test_description
    assert_equal "Showing/not showing guidance popup after mentees publish their profiles in self matched programs", Experiments::GuidancePopup.description
  end

  def test_experiment_config
    config = Experiments::GuidancePopup.experiment_config
    assert_equal ['Popup Not Shown', 'Popup Shown'], config[:alternatives]
  end

  def test_enabled
    assert Experiments::GuidancePopup.enabled?
  end

  def test_control_alternative
    assert_equal 'Popup Not Shown', Experiments::GuidancePopup.control_alternative
  end

  def test_is_experiment_applicable_for
    program = Program.first
    user = User.first
    program.stubs(:matching_by_mentee_alone?).returns(true)
    user.stubs(:is_student?).returns(true)
    user.stubs(:can_view_mentors?).returns(true)
    assert_false Experiments::GuidancePopup.is_experiment_applicable_for?("Program", user)
    assert Experiments::GuidancePopup.is_experiment_applicable_for?(program, user)

    program.stubs(:self_match_and_not_pbe?).returns(false)
    assert_false Experiments::GuidancePopup.is_experiment_applicable_for?(program, user)

    program.stubs(:self_match_and_not_pbe?).returns(true)
    user.stubs(:is_student?).returns(false)
    assert_false Experiments::GuidancePopup.is_experiment_applicable_for?(program, user)

    user.stubs(:is_student?).returns(true)
    user.stubs(:can_view_mentors?).returns(false)
    assert_false Experiments::GuidancePopup.is_experiment_applicable_for?(program, user)
  end

  def test_show_guidance_popup
    exp1 = Experiments::GuidancePopup.new(Experiments::GuidancePopup::Alternatives::ALTERNATIVE_B)
    assert exp1.show_guidance_popup?

    exp2 = Experiments::GuidancePopup.new(Experiments::GuidancePopup::Alternatives::CONTROL)
    assert_false exp2.show_guidance_popup?
    assert exp2.show_guidance_popup?(true)

    exp3 = Experiments::GuidancePopup.new
    assert_false exp3.show_guidance_popup?
    assert exp3.show_guidance_popup?(true)
  end

  def test_event_label_id_for_ga
    exp1 = Experiments::GuidancePopup.new(Experiments::GuidancePopup::Alternatives::ALTERNATIVE_B)
    assert_equal Experiments::GuidancePopup::Alternatives::GA_EVENT_LABEL_ID_MAPPING[Experiments::GuidancePopup::Alternatives::ALTERNATIVE_B], exp1.event_label_id_for_ga

    exp2 = Experiments::GuidancePopup.new(Experiments::GuidancePopup::Alternatives::CONTROL)
    assert_equal Experiments::GuidancePopup::Alternatives::GA_EVENT_LABEL_ID_MAPPING[Experiments::GuidancePopup::Alternatives::CONTROL], exp2.event_label_id_for_ga
  end
end