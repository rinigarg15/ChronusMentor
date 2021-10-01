class UserFavoritesController < ApplicationController
  allow :user => :is_student?
  allow :exec => :check_program_has_ongoing_mentoring_enabled, :only => [:create]

  def create
    @user_favorite = current_user.user_favorites.find_by(favorite_id: params[:user_favorite][:favorite_id]) || current_user.user_favorites.create!(user_favorite_params(:create))
  end

  def destroy
    @user_favorite = current_user.user_favorites.find(params[:id])
    @user_favorite.destroy
    redirect_to users_path(src: EngagementIndex::Src::BrowseMentors::REMOVE_USER_FAVORITE)
  end

private
  def user_favorite_params(action)
    params.require(:user_favorite).permit(UserFavorite::MASS_UPDATE_ATTRIBUTES[action])
  end
end