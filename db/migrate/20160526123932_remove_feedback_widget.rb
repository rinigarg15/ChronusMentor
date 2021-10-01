class RemoveFeedbackWidget< ActiveRecord::Migration[4.2]
  def up
    drop_table :feedbacks
    Feature.where(name: "feedback_widget").each do |feature|
      feature.destroy
    end
  end

  def down
    create_table :feedbacks do |t|
      t.integer :member_id
      t.integer :program_id
      t.string :subject
      t.text :comment
      t.text :url
      t.timestamps null: false
    end
  end
end
