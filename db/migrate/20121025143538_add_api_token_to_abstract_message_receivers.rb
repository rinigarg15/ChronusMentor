class AddApiTokenToAbstractMessageReceivers< ActiveRecord::Migration[4.2]
  def change
  	add_column :abstract_message_receivers, :api_token, :string
  end
end