class AbstractMessagesController < ApplicationController

  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization
  before_action :fetch_message

  allow exec: :can_be_viewed?

  def show_receivers
  end

  def show_detailed
    @from_inbox = (params[:from_inbox] == "true")
  end

  def show_collapsed
    collapsed_message_ids = params[:collapsed_message_ids].map(&:to_i)
    @messages_collection = @message.root.tree.select { |m| m.id.in?(collapsed_message_ids) } 
  end

  private

  def fetch_message
    @message = AbstractMessage.find params[:id]
  end

  def can_be_viewed?
    @message.can_be_viewed?(wob_member)
  end
end