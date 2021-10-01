require_relative './../../test_helper.rb'

class MentoringModel::MilestoneTemplateTest < ActiveSupport::TestCase
  def test_validations
    mentoring_model_milestone_template = MentoringModel::MilestoneTemplate.new
    assert_false mentoring_model_milestone_template.valid?
    assert_equal ["can't be blank"], mentoring_model_milestone_template.errors[:mentoring_model_id]
    assert_equal ["can't be blank"], mentoring_model_milestone_template.errors[:title]

    mentoring_model_milestone_template = MentoringModel::MilestoneTemplate.new(title: "Carrie")
    mentoring_model_milestone_template.mentoring_model_id = programs(:albers).default_mentoring_model.id
    assert mentoring_model_milestone_template.valid?
    assert mentoring_model_milestone_template.errors.blank?
  end  

  def test_translated_fields
    milestone_template = create_mentoring_model_milestone_template
    Globalize.with_locale(:en) do
      milestone_template.title = "english title"
      milestone_template.description = "english description"
      milestone_template.save!
    end
    Globalize.with_locale(:"fr-CA") do
      milestone_template.title = "french title"
      milestone_template.description = "french description"
      milestone_template.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", milestone_template.title
      assert_equal "english description", milestone_template.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", milestone_template.title
      assert_equal "french description", milestone_template.description
    end
  end

  def test_has_many_mentoring_model_task_templates
    milestone_template = create_mentoring_model_milestone_template
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    create_mentoring_model_task_template(milestone_template_id: milestone_template.id)
    
    assert_equal 3, milestone_template.mentoring_model_task_templates.size

    assert_difference "MentoringModel::TaskTemplate.count", -3 do
      milestone_template.destroy          
    end
  end

  def test_has_many_mentoring_model_task_templates_with_position
    milestone_template = create_mentoring_model_milestone_template
    tt1 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true, duration: 6)
    tt2 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true, duration: 1)
    tt3 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true, duration: 5)

    assert_equal 3, milestone_template.mentoring_model_task_templates.size
    assert_equal [tt2, tt3, tt1].map(&:id), milestone_template.reload.mentoring_model_task_templates.map(&:id)
  end

  def test_has_many_mentoring_model_facilitation_templates
    program = programs(:albers)
    milestone_template = create_mentoring_model_milestone_template
    facilitation_template = create_mentoring_model_facilitation_template(roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]), milestone_template_id: milestone_template.id)
    assert_equal [facilitation_template], milestone_template.reload.mentoring_model_facilitation_templates    
    assert_difference "MentoringModel::FacilitationTemplate.count", -1 do 
      milestone_template.destroy
    end
  end

  def test_update_start_dates
    program = programs(:albers)
    milestone_template = create_mentoring_model_milestone_template
    tt1 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true, duration: 6)
    tt2 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true, duration: 1)
    tt3 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true, duration: 10)
    tt4 = create_mentoring_model_task_template(milestone_template_id: milestone_template.id, required: true, duration: 5)

    ft1 = create_mentoring_model_facilitation_template(milestone_template_id: milestone_template.id, send_on: 2)
    assert_equal 1, milestone_template.update_start_dates
    assert_equal 1, milestone_template.start_date
    tt2.destroy
    assert_equal 2, milestone_template.update_start_dates
    assert_equal 2, milestone_template.start_date
    ft1.destroy
    assert_equal 5, milestone_template.update_start_dates
    assert_equal 5, milestone_template.start_date    
  end

  def test_versioning
    program = programs(:albers)
    milestone_template = create_mentoring_model_milestone_template
    assert_difference "milestone_template.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        milestone_template.update_attributes(title: "new title")
      end
    end

    assert_difference "milestone_template.versions.size", 1 do
      assert_difference "ChronusVersion.count", 1 do
        milestone_template.update_attributes(description: "new description")
      end
    end
  end

  def test_version_number
    milestone_template = create_mentoring_model_milestone_template
    assert_equal 1, milestone_template.version_number
    create_chronus_version(item: milestone_template, object_changes: "", event: ChronusVersion::Events::UPDATE)
    assert_equal 2, milestone_template.reload.version_number
  end
end