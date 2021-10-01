class MentorRecommendationNotification < ChronusActionMailer::Base
  
  @mailer_attributes = {
    :uid          => '7lr1yg13', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ADMIN_INITIATED_MATCHING,
    :title        => Proc.new{|program| "email_translations.mentor_recommendation_notification.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_recommendation_notification.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_recommendation_notification.subject".translate},
    :campaign_id  => CampaignConstants::MENTOR_RECOMMENDATION_NOTIFICATION_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :skip_default_salutation => true,
    :level        => EmailCustomization::Level::PROGRAM,
    :feature      => FeatureName::MENTOR_RECOMMENDATION,
    :listing_order => 1
  }

  def mentor_recommendation_notification(receiver, mentor_recommendation)
    @mentor_recommendation = mentor_recommendation
    @receiver = receiver
    @match_array = @receiver.get_student_cache_normalized
    @preferences = @mentor_recommendation.recommendation_preferences
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@receiver.program)
    set_username(@receiver, :name_only => true)
    setup_email(@receiver, :from => :admin)
    super
  end



  register_tags do

    tag :receiver_name, :description => Proc.new{'email_translations.mentor_recommendation_notification.tags.receiver_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      @receiver.member.name
    end

    tag :recommended_mentors_details, :description => Proc.new{|program| 'email_translations.mentor_recommendation_notification.tags.recommended_mentors_details.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{|program| program.get_mentor_recommendation_example_content} do
      render(partial: "/mentor_recommendations", locals: {preferences: @valid_recommendation_preferences, receiver: @receiver})
    end
    
  end

  self.register!

end