class RemoveDraftUsers< ActiveRecord::Migration[4.2]
  def up
    ActionMailer::Base.perform_deliveries = false
    User.where(state: "draft").destroy_all
  end

  def down
    # No down migration
  end
end
