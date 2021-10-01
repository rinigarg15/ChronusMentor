class CreateLoginTokens < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      create_table :login_tokens do |t|
        t.references  :member
        t.string      :token_code
        t.datetime    :last_used_at
        t.timestamps
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :login_tokens
    end
  end
end
