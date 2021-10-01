class AddContextProgramIdToMessages< ActiveRecord::Migration[4.2]
  def change
    add_column :messages, :context_program_id, :integer
  end
end
