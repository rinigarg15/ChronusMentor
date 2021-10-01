class ProfilePicturesController < ApplicationController
  include CommonProfileIncludes
  
  skip_before_action :back_mark_pages
  before_action :load_picture_owner_and_authorize, :only => [:edit, :update, :crop]

  # The Edit page is rendered even when there is no profile picture for the user.
  def edit
    @is_first_visit = params[:first_visit]
    @profile_picture = @profile_member.profile_picture || @profile_member.build_profile_picture

    prepare_profile_side_pane_data
  end

  # Updates profile picture with the new data. If the picture does not exist
  # yet, creates it.
  def update
    new_image_upload = params[:profile_picture][:image].present? || params[:profile_picture][:image_url].present?
    @profile_picture = @profile_member.profile_picture || @profile_member.build_profile_picture
    @profile_picture.attributes = profile_picture_params(:update)
    @profile_picture.not_applicable = false
    succesfully_saved = @profile_picture.save
    set_crop_params(@profile_picture, params[:profile_picture]) if succesfully_saved
    succesfully_saved &&= @profile_picture.reprocess_image if @profile_picture.cropping?
    if succesfully_saved
      if new_image_upload
        redirect_to crop_member_profile_picture_path(@profile_member)
      else
        flash[:notice] = "flash_message.user_flash.picture_update_success".translate
        redirect_to edit_member_path(@profile_member, ei_src: EngagementIndex::Src::EditProfile::PROFILE_PICTURE)
      end
    else
      prepare_profile_side_pane_data
      flash.now[:error] = "flash_message.user_flash.picture_update_failure".translate
      render :action => 'edit'
    end
  end

  def crop
    @profile_picture = @profile_member.profile_picture
  end

  ##############################################################################
  # PRIVATE
  ##############################################################################

  private

  def profile_picture_params(action)
    params.require(:profile_picture).permit(ProfilePicture::MASS_UPDATE_ATTRIBUTES[action])
  end

  # Loads the user from <i>params[:user_id]</i> and authorizes that the user
  # has permission to perform the action
  def load_picture_owner_and_authorize
    member_id = params[:member_id]
    @profile_member = @current_organization.members.find(member_id)

    # If viewed from within a program, fetch the User.
    @profile_user = @current_program.users.of_member(@profile_member).first if program_view?
    allow! :exec => authorize_member_action(@profile_member)
  end

  def set_crop_params(profile_picture, crop_params)
    geometry = profile_picture.image_geometry
    profile_picture.crop_x = crop_params[:crop_x] || 0
    profile_picture.crop_y = crop_params[:crop_y] || 0
    profile_picture.crop_h = crop_params[:crop_h] || geometry.smaller.to_i
    profile_picture.crop_w = crop_params[:crop_w] || geometry.smaller.to_i
    profile_picture.rotate = crop_params[:rotate] || 0
  end
end
