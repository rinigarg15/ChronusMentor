class AddFeatureCoachRating< ActiveRecord::Migration[4.2]
  def change
    if Feature.count > 0
      Feature.create_default_features
    end
    
    if Permission.count > 0
      Permission.create_default_permissions
      Role.administrative.each do |role|
        role.add_permission('view_coach_rating')
      end
    end
  end
end
