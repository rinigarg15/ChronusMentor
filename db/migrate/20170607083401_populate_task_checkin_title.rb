class PopulateTaskCheckinTitle< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      task_checkins_without_title = GroupCheckin.where(title: nil, checkin_ref_obj_type: MentoringModel::Task.name)
      id_to_task_map = MentoringModel::Task.where(id: task_checkins_without_title.pluck(:checkin_ref_obj_id)).includes(:translations).index_by(&:id)
      puts "Task Checkins without title: #{task_checkins_without_title.size}"

      task_checkins_without_title.each_with_index do |task_checkin, index|
        task_checkin.update_column(:title, id_to_task_map[task_checkin.checkin_ref_obj_id].title)
        print "." if ((index + 1) % 10 == 0)
      end
    end
  end

  def down
    #do nothing
  end
end