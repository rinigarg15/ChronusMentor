class CreateRecommendationPreferences< ActiveRecord::Migration[4.2]
  def change
    create_table :recommendation_preferences do |t|
      t.integer :user_id
      t.text :note
      t.integer :position
      t.integer :mentor_recommendation_id

      t.timestamps null: false
    end
  end
end
