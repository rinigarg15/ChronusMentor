class AddSpecificDateColumnToFacilitationTemplate< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_facilitation_templates, :specific_date, :datetime
  end
end
