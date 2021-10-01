module UserFavoritesHelper
  def add_favorite_action_hash(mentor)
    return {
      label: "feature.preferred_mentoring.action.add_to_list".translate(mentors: _mentors),
      js: "",
      remote: user_favorites_path(user_favorite: { favorite_id: mentor.id }, format: :js),
      method: "post"
    }
  end

  def remove_favorite_link(mentor, user_favorite)
    return link_to append_text_to_icon('fa fa-times', 'feature.preferred_mentoring.action.Remove'.translate), user_favorite_path(user_favorite),
      method: :delete,
      class: "btn btn-white btn-xs pull-right",
      data: {confirm: 'feature.preferred_mentoring.content.remove_mentor_confirm'.translate(mentor: h(_mentor), mentors: h(_mentors))}
  end
end