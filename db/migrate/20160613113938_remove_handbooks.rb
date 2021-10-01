class RemoveHandbooks< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      #Remove manage_handbooks permission - this will automatically destroy corresponding role_permissions
      Permission.find_by(name: "manage_handbooks").try(:destroy)
      #Drop Handbooks Table if they exist
      drop_table :handbooks
    end
  end

  def down
    ActiveRecord::Base.transaction do
      Permission.create!(:name => "manage_handbooks")

      create_table :handbooks do |t|
        t.string   :attachment_file_name
        t.string   :attachment_content_type
        t.integer  :attachment_file_size
        t.datetime :attachment_updated_at
        t.integer  :program_id
        t.boolean  :default
        t.boolean  :enabled, :default => true

        t.timestamps null: false
      end
    end
  end
end
