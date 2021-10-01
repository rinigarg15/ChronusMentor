class MigrateToMentoringModels< ActiveRecord::Migration[4.2]
  def up
    create_table :mentoring_models do |t|
      t.string :title
      t.text :description
      t.boolean :default, default: false
      t.belongs_to :program
      t.integer :mentoring_period
      t.timestamps null: false
    end

    add_index :mentoring_models, :program_id

    say_with_time "Renaming association column names" do
      rename_program_id :mentoring_model_task_templates
      rename_program_id :mentoring_model_goal_templates
      rename_program_id :mentoring_model_milestone_templates
      rename_program_id :mentoring_model_facilitation_templates
    end

    say_with_time "Migrating Programs" do
      Program.active.find_each do |program|
        ActiveRecord::Base.transaction do
          say "#{program.name} - Mentoring Model Creation and Object Role Permissions", true
          mentoring_model = create_and_assign_mentoring_model!(program)
          ObjectRolePermission.where(ref_obj_type: Program.superclass.name, ref_obj_id: program.id).each do |object_role_permission|
            object_role_permission.ref_obj = mentoring_model
            object_role_permission.save!
          end
          migrate_entities(MentoringModel::TaskTemplate, mentoring_model)
          migrate_entities(MentoringModel::GoalTemplate, mentoring_model)
          migrate_entities(MentoringModel::MilestoneTemplate, mentoring_model)
          migrate_entities(MentoringModel::FacilitationTemplate, mentoring_model)
        end
      end
    end
  end

  def down
    say_with_time "Down Migrating Programs" do
      Program.active.find_each do |program|
        ActiveRecord::Base.transaction do
          mentoring_model = program.mentoring_models.default.first
          say "#{program.name} - Reassociating Mentoring Models and Object Role Permissions", true
          ObjectRolePermission.where(ref_obj_type: MentoringModel.name, ref_obj_id: mentoring_model.id).each do |object_role_permission|
            object_role_permission.ref_obj = program
            object_role_permission.save!
          end
          say "#{program.name} - Reassociating Mentoring Model Entities", true
          migrate_entities MentoringModel::TaskTemplate, mentoring_model, false
          migrate_entities MentoringModel::GoalTemplate, mentoring_model, false
          migrate_entities MentoringModel::MilestoneTemplate, mentoring_model, false
          migrate_entities MentoringModel::FacilitationTemplate, mentoring_model, false
        end
      end
    end

    drop_table :mentoring_models
    remove_index :mentoring_models, :program_id
    say_with_time "Renaming association column names" do
      rename_program_id :mentoring_model_task_templates, false 
      rename_program_id :mentoring_model_goal_templates, false
      rename_program_id :mentoring_model_milestone_templates, false
      rename_program_id :mentoring_model_facilitation_templates, false
    end
  end

  private

  def migrate_entities(klass, mentoring_model, up_migration = true)
    changeable_mentoring_model_id, new_mentoring_model_id = up_migration ? [mentoring_model.program_id, mentoring_model.id] : [mentoring_model.id, mentoring_model.program_id]
    klass.where(mentoring_model_id: changeable_mentoring_model_id).update_all(mentoring_model_id: new_mentoring_model_id)
  end

  def rename_program_id(table_name, up_migration = true)
    remove_column, new_column = up_migration ? [:program_id, :mentoring_model_id] : [:mentoring_model_id, :program_id]
    remove_index table_name, remove_column
    rename_column table_name, remove_column, new_column
    add_index table_name, new_column, name: "#{table_name}_on_#{new_column}"
  end

  def create_and_assign_mentoring_model!(program)
    program.mentoring_models.create!(
      title: "#{program.name} #{"feature.mentoring_model.label.Template".translate}",
      default: true,
      mentoring_period: Program::DEFAULT_MENTORING_PERIOD.to_i,
      skip_default_permissions: true
    )
  end
end
