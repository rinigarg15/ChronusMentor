class ChangeFacilitationMessagesinEy< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        organization = Common::RakeModule::Utils.fetch_programs_and_organization("chronus.com", "eycollegemap")[1]
        program_ids = organization.programs.where.not(root: "p1").pluck(:id)
        facilitation_templates = MentoringModel::FacilitationTemplate.includes(:translations).joins(:mentoring_model).where(mentoring_models: { program_id: program_ids }).where.not("message LIKE '%{{mentoring_area_button}}%'")
        facilitation_templates.each do |facilitation_template|
          facilitation_template.update_attributes(message: "#{facilitation_template.message} <br/>{{mentoring_area_button}}")
        end
      end
    end
  end

  def down
    # Do nothing
  end
end
