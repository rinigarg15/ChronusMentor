require_relative './../../../../test_helper.rb'

class Experiments::PopularCategoriesTest < ActionView::TestCase
  def test_title
    assert_equal "Preference Categories", Experiments::PopularCategories.title
  end

  def test_description
    assert_equal "Showing/not showing preference categories in self matched programs", Experiments::PopularCategories.description
  end

  def test_experiment_config
    config = Experiments::PopularCategories.experiment_config
    assert_equal ['Preference Categories Not Shown', 'Preference Categories Shown'], config[:alternatives]
  end

  def test_enabled
    assert Experiments::PopularCategories.enabled?
  end

  def test_control_alternative
    assert_equal 'Preference Categories Not Shown', Experiments::PopularCategories.control_alternative
  end

  def test_is_experiment_applicable_for
    program = Program.first
    user = User.first
    user.stubs(:can_view_preferece_based_mentor_lists?).returns(true)
    assert_false Experiments::PopularCategories.is_experiment_applicable_for?("Program", user)
    assert Experiments::PopularCategories.is_experiment_applicable_for?(program, user)
    user.stubs(:can_view_preferece_based_mentor_lists?).returns(false)
    assert_false Experiments::PopularCategories.is_experiment_applicable_for?(program, user)
  end

  def test_show_preference_categories
    exp1 = Experiments::PopularCategories.new(Experiments::PopularCategories::Alternatives::ALTERNATIVE_B)
    assert exp1.show_preference_categories?

    exp2 = Experiments::PopularCategories.new(Experiments::PopularCategories::Alternatives::CONTROL)
    assert_false exp2.show_preference_categories?
    assert exp2.show_preference_categories?(true)

    exp3 = Experiments::PopularCategories.new
    assert_false exp3.show_preference_categories?
    assert exp3.show_preference_categories?(true)
  end

  def test_event_label_id_for_ga
    exp1 = Experiments::PopularCategories.new(Experiments::PopularCategories::Alternatives::ALTERNATIVE_B)
    assert_equal Experiments::PopularCategories::Alternatives::GA_EVENT_LABEL_ID_MAPPING[Experiments::PopularCategories::Alternatives::ALTERNATIVE_B], exp1.event_label_id_for_ga

    exp2 = Experiments::PopularCategories.new(Experiments::PopularCategories::Alternatives::CONTROL)
    assert_equal Experiments::PopularCategories::Alternatives::GA_EVENT_LABEL_ID_MAPPING[Experiments::PopularCategories::Alternatives::CONTROL], exp2.event_label_id_for_ga
  end
end