MailerTag.register_tags(:recommended_mentors_tag) do |t|
  t.tag :recommended_mentors, description: Proc.new{|program| 'feature.email.tags.campaign_tags.recommended_mentors.description'.translate(program.return_custom_term_hash) }, example: Proc.new{'feature.email.tags.campaign_tags.recommended_mentors.example_html_v1'.translate }, name: Proc.new{|program| 'feature.email.tags.campaign_tags.recommended_mentors.name'.translate(program.return_custom_term_hash) } do
    set_recommendations_selected_mentors_and_match_info
    url_options = url_options_for_recommendations(@program)
    render(partial: '/recommended_mentors', locals: {selected_mentors: @selected_mentors, mentee_can_view_mentors: @mentee_can_view_mentors, url_options: url_options, program: @program, match_info: @match_info, show_view_favorites_button: @show_view_favorites_button, mentee: (@mentee||@user)}) if show_recommended_mentors?
  end
end

private

def set_recommendations_selected_mentors_and_match_info
  mentor_recommendations_service = get_mentor_recommendations_service
  @selected_mentors = mentor_recommendations_service.get_recommendations_for_mail
  @match_info = mentor_recommendations_service.get_match_info_for(@selected_mentors)
  @show_view_favorites_button = mentor_recommendations_service.show_view_favorites_button?
end

def get_recommendations_for
  @request.class == MentorRequest ? MentorRecommendationsService::RecommendationsFor::ONGOING : MentorRecommendationsService::RecommendationsFor::FLASH
end

def get_mentor_recommendations_service
  @request.present? ? MentorRecommendationsService.new(@mentee, recommendations_for: get_recommendations_for, only_favorite_and_top_matches: true) : MentorRecommendationsService.new(@user)
end

def show_recommended_mentors?
  @mentee_can_view_mentors = (@mentee||@user).can_view_mentors?
  @selected_mentors.present? || @mentee_can_view_mentors
end