class OneTimeFlagsController < ApplicationController

  respond_to :js, only: :create
  allow :exec => :logged_in_at_current_level?

  def create
    user = params[:update_original_user] ? current_member.user_in_program(current_program) : current_user
    user.one_time_flags.find_or_create_by!(message_tag: params[:TAG])
    head :ok
  end

end