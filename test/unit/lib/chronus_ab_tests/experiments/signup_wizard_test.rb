require_relative './../../../../test_helper.rb'

class Experiments::SignupWizardTest < ActionView::TestCase
  def test_title
    assert_equal "Signup Wizard", Experiments::SignupWizard.title
  end

  def test_description
    assert_equal "Experiment to test if showing a wizard during signup increases the completion rate", Experiments::SignupWizard.description
  end

  def test_experiment_config
    config = Experiments::SignupWizard.experiment_config
    assert_equal ['Wizard not shown', 'Wizard shown'], config[:alternatives]
  end

  def test_enabled
    assert_false Experiments::SignupWizard.enabled?
  end

  def test_control_alternative
    assert_equal Experiments::SignupWizard::Alternatives::CONTROL, Experiments::SignupWizard.control_alternative
  end

  def test_is_experiment_applicable_for
    assert Experiments::SignupWizard.is_experiment_applicable_for?('prog', 'user')
  end

  def test_render_wizard
    Experiments::SignupWizard.any_instance.stubs(:last_section_content_and_title).returns(["some circle", "some circle title"])
    org = programs(:org_primary)
    sections = org.sections

    experiment_1 = Experiments::SignupWizard.new
    assert_nil experiment_1.render_wizard(sections, MembersController::EditSection::GENERAL, -1, users(:f_mentor), programs(:albers))

    experiment_2 = Experiments::SignupWizard.new(Experiments::SignupWizard::Alternatives::CONTROL)
    assert_nil experiment_2.render_wizard(sections, MembersController::EditSection::GENERAL, -1, users(:f_mentor), programs(:albers))

    experiment_3 = Experiments::SignupWizard.new(Experiments::SignupWizard::Alternatives::ALTERNATIVE_B)
    html_content_1 = to_html(experiment_3.render_wizard(sections, MembersController::EditSection::GENERAL, -1, users(:f_admin), programs(:albers)))

    # Basic information section active, has profile sections
    assert_select html_content_1, "div.row-fluid" do
      assert_select "div.cui-signup-wizard" do
        assert_select "span.wizard-circle", :count => sections.size + 1
        assert_select "span.wizard-circle.active", :count => 1
        assert_select "span.wizard-circle.active", :text => "1", :count => 1
        assert_select "span.wizard-circle.done", :count => 0
        assert_select "span.wizard-label", :count => sections.size + 1
        assert_select "div.wizard-title", :count => sections.size + 1
        assert_select "div.wizard-title.active", :count => 1
        assert_select "div.wizard-title.active", :text => 'Summary', :count => 1
        assert_select "div.wizard-title.done", :count => 0
        assert_select "span.wizard-bar", :count => sections.size
        assert_select "span.wizard-bar.active", :count => 0
        assert_select "span.wizard-bar.done", :count => 0
      end
    end

    # Basic information section active, no profile sections
    html_content_2 = to_html(experiment_3.render_wizard([], MembersController::EditSection::GENERAL, -1, users(:f_admin), programs(:albers)))

    assert_select html_content_2, "div.row-fluid" do
      assert_select "div.cui-signup-wizard" do
        assert_select "span.wizard-circle", :count => 1
        assert_select "span.wizard-circle.active", :count => 1
        assert_select "span.wizard-circle.active", :text => '1', :count => 1
        assert_select "span.wizard-circle.done", :count => 0
        assert_select "span.wizard-label", :count => 1
        assert_select "div.wizard-title", :count => 1
        assert_select "div.wizard-title.active", :count => 1
        assert_select "div.wizard-title.active", :text => 'Summary', :count => 1
        sections.collect(&:title)[1]
        assert_select "div.wizard-title.done", :count => 0
        assert_select "span.wizard-bar", :count => 0
        assert_select "span.wizard-bar.active", :count => 0
        assert_select "span.wizard-bar.done", :count => 0
      end
    end

    # Profile section active
    html_content_3 = to_html(experiment_3.render_wizard(sections, MembersController::EditSection::PROFILE, 1, users(:f_admin), programs(:albers)))

    assert_select html_content_3, "div.row-fluid" do
      assert_select "div.cui-signup-wizard" do
        assert_select "span.wizard-circle", :count => sections.size + 1
        assert_select "span.wizard-circle.active", :count => 1
        assert_select "span.wizard-circle.active", :text => '3', :count => 1
        assert_select "span.wizard-circle.done", :count => 2
        assert_select "span.wizard-label", :count => sections.size + 1
        assert_select "div.wizard-title", :count => sections.size + 1
        assert_select "div.wizard-title.active", :count => 1
        assert_select "div.wizard-title.active", :text => sections.collect(&:title)[1], :count => 1
        assert_select "div.wizard-title.done", :text => 'Summary', :count => 1
        assert_select "div.wizard-title.done", :count => 2
        assert_select "span.wizard-bar", :count => sections.size
        assert_select "span.wizard-bar.active", :count => 1
        assert_select "span.wizard-bar.done", :count => 1
      end
    end

    assert_select html_content_3, "div.row-fluid", :text => "1234567some circleSummaryBasic InformationWork and EducationMentoring ProfileMore InformationMore Information 2More Information Studentssome circle title"
  end

  def test_last_section_content_and_title
    experiment = Experiments::SignupWizard.new(Experiments::SignupWizard::Alternatives::ALTERNATIVE_B)
    content1, content2 = experiment.last_section_content_and_title(users(:f_student), programs(:albers), MembersController::EditSection::GENERAL, [])
    assert content1.empty?
    assert content2.empty?

    content1, content2 = experiment.last_section_content_and_title(users(:f_mentor), programs(:albers), MembersController::EditSection::GENERAL, [])
    html_content_1_1 = to_html(content1)
    html_content_1_2 = to_html(content2)

    assert_select html_content_1_1, "span.wizard-bar", :count => 1
    assert_select html_content_1_1, "span.wizard-bar.active", :count => 0
    assert_select html_content_1_1, "span.wizard-circle", :count => 1 do
      assert_select "span.wizard-label", :count => 1
    end
    assert_select html_content_1_1, "span.wizard-circle.active", :count => 0

    assert_select html_content_1_2, "div.wizard-title", :text => "Mentoring Connection Settings", :count => 1
    assert_select html_content_1_2, "div.wizard-title.active", :count => 0

    content1, content2 = experiment.last_section_content_and_title(users(:f_mentor), programs(:albers), MembersController::EditSection::MENTORING_SETTINGS, [])
    html_content_2_1 = to_html(content1)
    html_content_2_2 = to_html(content2)

    assert_select html_content_2_1, "span.wizard-bar.active", :count => 1
    assert_select html_content_2_1, "span.wizard-circle.active", :count => 1 do
      assert_select "span.wizard-label", :count => 1
    end

    assert_select html_content_2_2, "div.wizard-title.active", :text => "Mentoring Connection Settings", :count => 1
  end
end
