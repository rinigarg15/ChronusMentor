class UpdateConnectionLimitPermission< ActiveRecord::Migration[4.2]
  def up
    ActionMailer::Base.perform_deliveries = false
    ActiveRecord::Base.transaction do
      Program.where(allow_mentor_update_maxlimit: false).each do |program|
        program.update_attributes!(:connection_limit_permission => Program::ConnectionLimit::NONE)
      end
    end
  end

  def down
  end
end
