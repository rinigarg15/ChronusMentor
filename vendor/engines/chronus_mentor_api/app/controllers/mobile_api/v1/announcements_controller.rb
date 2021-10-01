class MobileApi::V1::AnnouncementsController < MobileApi::V1::BasicController
  before_action :authenticate_user
  before_action :fetch_announcement, :only => [:show]

  def index
    @announcements = @current_program.announcements.for_user(current_user).published.not_expired.ordered
    render_success("announcements/index")
  end

  # The scopes on announcement in #index and #show are different
  # because we are respecting the same conditions as web app in respective actions.
  def show
    render_success("announcements/show")
  end

  private

  def fetch_announcement
    @announcement = @current_program.announcements.for_user(current_user).find(params[:id])
  end

end
