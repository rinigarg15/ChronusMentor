class RemoveFacilitationMessages< ActiveRecord::Migration[4.2]
  def up
    drop_table :facilitation_messages
    drop_table :facilitation_message_translations
    Feature.where(name: "facilitate_messages").each do |feature|
      feature.destroy
    end
    Permission.find_by(name: "manage_facilitation_messages").try(:destroy)
  end

  def down
    Permission.create!(:name => "manage_facilitation_messages")
    create_table :facilitation_messages do |t|
      t.string :subject
      t.text :message
      t.integer :send_on
      t.integer :program_id
      t.boolean :enabled
      t.timestamps null: false
    end
  end
end
