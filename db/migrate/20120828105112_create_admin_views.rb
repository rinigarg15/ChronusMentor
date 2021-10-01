class CreateAdminViews< ActiveRecord::Migration[4.2]
  def change
    create_table :admin_views do |t|
      t.string :title
      t.integer :program_id, null: false
      t.text :filter_params
      t.integer :default_view
      t.timestamps null: false
    end
    if Feature.count > 0
      Feature.create_default_features
    end
    Organization.active.all.each do |organization|
      organization.programs.each do |program|
        program.create_default_admin_views
        puts "Default Admin Views for #{organization.name} - #{program.name} created."
      end
    end 
  end
end
