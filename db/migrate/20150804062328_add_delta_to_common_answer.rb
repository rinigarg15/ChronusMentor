class AddDeltaToCommonAnswer< ActiveRecord::Migration[4.2]
  def change
    add_column :common_answers, :delta, :boolean, :default => false
  end
end
