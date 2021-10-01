class AddAutoTerminateReasonToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :auto_terminate_reason_id, :integer
  end
end
