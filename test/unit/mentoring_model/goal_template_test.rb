require_relative './../../test_helper.rb'

class MentoringModel::GoalTemplateTest < ActiveSupport::TestCase

  def test_validate_presence_of_goal_template_fields
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    goal_template = mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    assert goal_template.valid?

    goal_template = mentoring_model.mentoring_model_goal_templates.create(description: "Hello1Desc")
    assert_false goal_template.valid?
    assert_equal ["can't be blank"], goal_template.errors[:title]
    
    goal_template = mentoring_model.mentoring_model_goal_templates.create(title: "Hello1")
    assert goal_template.valid?
    
    goal_template = MentoringModel::GoalTemplate.create(title: "Hello1", description: "Hello1Desc")
    assert_false goal_template.valid?
    assert_equal ["can't be blank"], goal_template.errors[:mentoring_model_id]
  end

  def test_translated_fields
    mentoring_model = programs(:albers).default_mentoring_model
    goal_template = mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    Globalize.with_locale(:en) do
      goal_template.title = "english title"
      goal_template.description = "english description"
      goal_template.save!
    end
    Globalize.with_locale(:"fr-CA") do
      goal_template.title = "french title"
      goal_template.description = "french description"
      goal_template.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", goal_template.title
      assert_equal "english description", goal_template.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", goal_template.title
      assert_equal "french description", goal_template.description
    end
  end

  def test_has_many_task_templates
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    goal_template = mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    
    assert_equal 3, goal_template.task_templates.size
  end

  def test_versioning
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    goal_template = mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    assert_difference "goal_template.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        goal_template.update_attributes(title: "new title")
      end
    end

    assert_difference "goal_template.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        goal_template.update_attributes(description: "new description")
      end
    end
  end

  def test_version_number
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    goal_template = mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    assert_equal 1, goal_template.version_number
    create_chronus_version(item: goal_template, object_changes: "", event: ChronusVersion::Events::UPDATE)
    assert_equal 2, goal_template.reload.version_number
  end
end
