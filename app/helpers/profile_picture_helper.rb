module ProfilePictureHelper
  # Helper proxy for <i>common/edit_picture_fields</i> partial.
  #
  # ==== Params
  # user  ::  the user for whom to render the picture fields
  # view  ::  context, either edit_profile or add_mentor
  #
  def edit_picture_field(member, form_handle, show_image = false)
    render 'profile_pictures/edit_profile_picture_fields', member: member, picture: form_handle, show_image: show_image
  end

  def get_rotate_buttons
    common_actions = []
    rotate_class = "btn btn-white cjs-profile-pic-rotate"

    common_actions << link_to(get_icon_content("fa fa-rotate-left") + set_screen_reader_only_content("feature.profile.content.rotate_left".translate), "javascript:void(0);", class: rotate_class, data: {degree: "-90"})
    common_actions << link_to(get_icon_content("fa fa-rotate-right") + set_screen_reader_only_content("feature.profile.content.rotate_right".translate), "javascript:void(0);", class: rotate_class, data: {degree: "90"})
    return common_actions
  end
end
