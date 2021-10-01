class AddMaximumLoginAttemptsLoginCounter< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :maximum_login_attempts, :integer, :default => Organization::DISABLE_MAXIMUM_LOGIN_ATTEMPTS
    add_column :members, :failed_login_attempts, :integer, :default => 0
  end
end
