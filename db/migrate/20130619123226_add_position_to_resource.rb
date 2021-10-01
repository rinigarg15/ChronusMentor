class AddPositionToResource< ActiveRecord::Migration[4.2]
  def change
    ActiveRecord::Base.transaction do
      add_column :resources, :position, :integer
      Organization.all.each do |organization|
        organization.resources.order("updated_at DESC, id DESC").each_with_index do |resource, index|
          resource.position = index + 1
          resource.save!
        end
      end
    end
  end
end
