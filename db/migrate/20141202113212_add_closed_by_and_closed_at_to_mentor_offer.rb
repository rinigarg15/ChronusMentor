class AddClosedByAndClosedAtToMentorOffer< ActiveRecord::Migration[4.2]
  def change
    add_column :mentor_offers, :closed_by_id, :integer
    add_column :mentor_offers, :closed_at, :datetime
  end
end
