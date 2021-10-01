class AddDeltaToMentorOffer< ActiveRecord::Migration[4.2]
  def change
    add_column :mentor_offers, :delta, :boolean, :default => false
  end
end
