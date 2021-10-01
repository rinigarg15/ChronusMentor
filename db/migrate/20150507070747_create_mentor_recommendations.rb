class CreateMentorRecommendations< ActiveRecord::Migration[4.2]
  def change
    create_table :mentor_recommendations do |t|
      t.integer :program_id
      t.integer :status
      t.integer :sender_id
      t.integer :receiver_id

      t.timestamps null: false
    end
  end
end
