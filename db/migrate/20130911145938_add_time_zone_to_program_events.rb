class AddTimeZoneToProgramEvents< ActiveRecord::Migration[4.2]
  def change
    add_column :program_events, :time_zone, :string
  end
end
