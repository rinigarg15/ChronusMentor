# Controller for 'Chronus super-user console'
class ChronusSessionsController < ApplicationController
  # session key to store whether we are currently inside super console.
  SUPER_CONSOLE_SESSION_KEY = 'super_console'

  skip_before_action :login_required_in_program, :require_program, :require_organization

  # Login page for super console
  def new
  end

  # Login action - creates a chronus session
  def create
    if APP_CONFIG[:super_console_pass_phrase] == params[:passphrase]
      session[SUPER_CONSOLE_SESSION_KEY] = true
      redirect_to_back_mark_or_default root_path
    else
      flash.now[:error] = "flash_message.chronus_session_flash.create_failure".translate
      render :action => 'new'
    end
  end

  # Logs out of super console
  def destroy
    session[SUPER_CONSOLE_SESSION_KEY] = nil
    redirect_to root_path
  end
end
