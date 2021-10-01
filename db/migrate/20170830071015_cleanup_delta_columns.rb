class CleanupDeltaColumns< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :members do |m|
        m.remove_column :delta
      end
      Lhm.change_table :users do |m|
        m.remove_column :delta
      end
      Lhm.change_table :groups do |m|
        m.remove_column :delta
      end
      Lhm.change_table :messages do |m|
        m.remove_column :delta
      end
      Lhm.change_table :mentor_requests do |m|
        m.remove_column :delta
      end
      Lhm.change_table :meetings do |m|
        m.remove_column :delta
      end
      Lhm.change_table :mentor_offers do |m|
        m.remove_column :delta
      end
      Lhm.change_table :common_answers do |m|
        m.remove_column :delta
      end
      Lhm.change_table :articles do |m|
        m.remove_column :delta
      end
      Lhm.change_table :qa_questions do |m|
        m.remove_column :delta
      end
      Lhm.change_table :three_sixty_surveys do |m|
        m.remove_column :delta
      end
      Lhm.change_table :three_sixty_survey_assessees do |m|
        m.remove_column :delta
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :members do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :users do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :groups do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :messages do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :mentor_requests do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :meetings do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :mentor_offers do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :common_answers do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :articles do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :qa_questions do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :three_sixty_surveys do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
      Lhm.change_table :three_sixty_survey_assessees do |m|
        m.add_column :delta, "tinyint(1) DEFAULT NULL"
      end
    end
  end
end
