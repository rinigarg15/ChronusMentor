class RemoveMentoringAreaScraps< ActiveRecord::Migration[4.2]
  def up
    drop_table :scraps
  end

  def down
  end
end
