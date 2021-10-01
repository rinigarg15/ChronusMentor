class AddColumnPublishedAtForMentorRecommendation < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :mentor_recommendations do |t|
        t.add_column :published_at, "datetime DEFAULT NULL"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :mentor_recommendations do |t|
        t.remove_column :published_at
      end
    end
  end
end
