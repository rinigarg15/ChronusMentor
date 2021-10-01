class DataScrubber
  INDEPENDENT_OBJECTS = [
    Flag,
    JobLog,
    Rating,
    Subscription,
    RoleReference,
    VulnerableContentLog,
    EventInvite,
    ProgramEventUser,
    ArticleListItem,
    ProgramActivity,
    Connection::Activity,
    PushNotification,
    PendingNotification,
    CampaignManagement::EmailEventLog,
    CampaignManagement::CampaignMessageAnalytics,
    CampaignManagement::ProgramInvitationCampaignStatus,
    CampaignManagement::ProgramInvitationCampaignMessageJob,
    AdminMessages::Receiver,
    RoleResource
  ]

  def initialize(options = {})
    @program = options[:program]
    @organization = @program.try(:organization) || options[:organization]
    @program_or_organization = @program.presence || @organization
  end

  def scrub_announcements(announcement_ids = @program.announcement_ids)
    scrub(Announcement, announcement_ids, {
      assoc_objects_for_deletion: [
        [PushNotification, ref_obj_id: announcement_ids, ref_obj_type: Announcement.name],
        [PendingNotification, ref_obj_id: announcement_ids, ref_obj_type: Announcement.name],
        [RoleReference, ref_obj_id: announcement_ids, ref_obj_type: Announcement.name],
        [VulnerableContentLog, ref_obj_id: announcement_ids, ref_obj_type: Announcement.name],
        [JobLog, loggable_object_id: announcement_ids, loggable_object_type: Announcement.name]
      ],
      assoc_scrubbers: [
        [:scrub_recent_activities, RecentActivity.where(ref_obj_id: announcement_ids, ref_obj_type: Announcement.name)]
      ]
    })
  end

  def scrub_qa_questions(qa_question_ids = @program.qa_question_ids)
    scrub(QaQuestion, qa_question_ids, {
      assoc_objects_for_deletion: [
        [Flag, content_id: qa_question_ids, content_type: QaQuestion.name],
        [Rating, rateable_id: qa_question_ids, rateable_type: QaQuestion.name]
      ],
      assoc_scrubbers: [
        [:scrub_qa_answers, QaAnswer.where(qa_question_id: qa_question_ids)],
        [:scrub_recent_activities, RecentActivity.where(ref_obj_id: qa_question_ids, ref_obj_type: QaQuestion.name)]
      ]
    })
  end

  def scrub_qa_answers(qa_answer_ids = @program.qa_answer_ids)
    scrub(QaAnswer, qa_answer_ids, {
      assoc_objects_for_deletion: [
        [Flag, content_id: qa_answer_ids, content_type: QaAnswer.name],
        [Rating, rateable_id: qa_answer_ids, rateable_type: QaAnswer.name]
      ],
      assoc_scrubbers: [
        [:scrub_recent_activities, RecentActivity.where(ref_obj_id: qa_answer_ids, ref_obj_type: QaAnswer.name)]
      ]
    })
  end

  def scrub_program_events(program_event_ids = @program.program_event_ids)
    scrub(ProgramEvent, program_event_ids, {
      assoc_objects_for_deletion: [
        [EventInvite, program_event_id: program_event_ids],
        [ProgramEventUser, program_event_id: program_event_ids],
        [RoleReference, ref_obj_id: program_event_ids, ref_obj_type: ProgramEvent.name],
        [VulnerableContentLog, ref_obj_id: program_event_ids, ref_obj_type: ProgramEvent.name],
        [JobLog, loggable_object_id: program_event_ids, loggable_object_type: ProgramEvent.name]
      ],
      assoc_scrubbers: [
        [:scrub_recent_activities, RecentActivity.where(ref_obj_id: program_event_ids, ref_obj_type: ProgramEvent.name)]
      ]
    })
  end

  def scrub_survey_answers(survey_ids = @program.survey_ids)
    scrub(SurveyAnswer, SurveyAnswer.where(survey_id: survey_ids).pluck(:id))
  end

  def scrub_recent_activities(ra_ids = @program.recent_activity_ids)
    scrub(RecentActivity, ra_ids, {
      assoc_objects_for_deletion: [
        [Connection::Activity, recent_activity_id: ra_ids],
        [ProgramActivity, activity_id: ra_ids]
      ]
    })
  end

  def scrub_topics(topic_ids = @program.topic_ids)
    scrub(Topic, topic_ids, {
      assoc_objects_for_deletion: [
        [Subscription, ref_obj_id: topic_ids, ref_obj_type: Topic.name]
      ],
      assoc_scrubbers: [
        [:scrub_posts, Post.where(topic_id: topic_ids)]
      ]
    })
  end

  def scrub_forums(forum_ids = @program.forum_ids)
    scrub(Forum, forum_ids, {
      assoc_objects_for_deletion: [
        [RoleReference, ref_obj_id: forum_ids, ref_obj_type: Forum.name],
        [Subscription, ref_obj_id: forum_ids, ref_obj_type: Forum.name]
      ],
      assoc_scrubbers: [
        [:scrub_recent_activities, RecentActivity.where(ref_obj_id: forum_ids, ref_obj_type: Forum.name)],
        [:scrub_topics, Topic.where(forum_id: forum_ids)]
      ]
    })
  end

  def scrub_articles(article_ids = @program.article_ids)
    scrub(Article, article_ids, {
      additional_eager_loadables: [
        :article_content
      ],
      assoc_objects_for_deletion: [
        [Rating, rateable_id: article_ids, rateable_type: Article.name],
        [Flag, content_type: Article.name, content_id: article_ids],
        [PendingNotification, ref_obj_id: article_ids, ref_obj_type: Article.name]
      ],
      assoc_scrubbers: [
        [:scrub_article_publications, Article::Publication.where(article_id: article_ids)],
        [:scrub_recent_activities, RecentActivity.where(ref_obj_id: article_ids, ref_obj_type: Article.name)],
        [:scrub_article_contents, ArticleContent.where(id: Article.where(id: article_ids).pluck(:article_content_id))]
      ]
    })
  end

  def scrub_program_invitations(program_invitation_ids = @program.program_invitation_ids)
    scrub(ProgramInvitation, program_invitation_ids, {
      assoc_objects_for_deletion: [
        [VulnerableContentLog, ref_obj_id: program_invitation_ids, ref_obj_type: ProgramInvitation.name],
        [RoleReference, ref_obj_id: program_invitation_ids, ref_obj_type: ProgramInvitation.name],
        [JobLog, ref_obj_id: program_invitation_ids, ref_obj_type: ProgramInvitation.name],
        [CampaignManagement::ProgramInvitationCampaignMessageJob, abstract_object_id: program_invitation_ids]
      ]
    })
  end

  def scrub_program_invitation_campaign_analytics(campaign_message_ids = @program.program_invitation_campaign.campaign_message_ids)
    scrub(nil, nil, {
      assoc_objects_for_deletion: [
        [CampaignManagement::CampaignMessageAnalytics, campaign_message_id: campaign_message_ids]
      ],
      assoc_scrubbers: [
        [:scrub_campaign_emails, CampaignManagement::CampaignEmail.where(campaign_message_id: campaign_message_ids)]
      ]
    })
  end

  def scrub_admin_messages(admin_message_ids = @program_or_organization.admin_message_ids)
    scrub(AdminMessage, admin_message_ids, {
      assoc_objects_for_deletion: [
        [PushNotification, ref_obj_id: admin_message_ids, ref_obj_type: AbstractMessage.name],
        [CampaignManagement::EmailEventLog, message_id: admin_message_ids, message_type: AbstractMessage.name],
        [AdminMessages::Receiver, message_id: admin_message_ids]
      ]
    })
  end

  def scrub_resources(resource_ids = @program_or_organization.resource_ids)
    scrub(Resource, resource_ids, {
      assoc_objects_for_deletion: [
        [Rating, rateable_id: resource_ids, rateable_type: Resource.name]
      ],
      assoc_scrubbers: [
        [:scrub_resource_publications, ResourcePublication.where(resource_id: resource_ids)]
      ]
    })
  end

  def scrub_resource_publications(resource_publication_ids = @program.resource_publication_ids)
    scrub(ResourcePublication, resource_publication_ids, {
      assoc_objects_for_deletion: [
        [RoleResource, resource_publication_id: resource_publication_ids],
      ]
    })
  end

  private

  def scrub(klass, object_ids, scrub_options = {})
    begin
      initial_dj_config = Delayed::Worker.delay_jobs
      initial_mail_config = ActionMailer::Base.perform_deliveries
      Delayed::Worker.delay_jobs = false
      ActionMailer::Base.perform_deliveries = false
      ActiveRecord::Base.transaction do
        initialize_scrub_options(scrub_options)
        raise "Non independent objects passed to delete all!" if (scrub_options[:assoc_objects_for_deletion].collect(&:first) - INDEPENDENT_OBJECTS).present?
        scrub_options[:assoc_objects_for_deletion].each do |assoc_object_for_deletion|
          assoc_object_for_deletion[0].where(assoc_object_for_deletion[1]).delete_all
        end
        scrub_options[:assoc_scrubbers].each do |assoc_scrubber|
          send(assoc_scrubber[0], assoc_scrubber[1].pluck(:id)) if assoc_scrubber[1].present?
        end
        if klass.present?
          DelayedEsDocument.skip_es_delta_indexing(auto_reindex: true) do
            scrub_translations_and_versions(klass, object_ids, scrub_options)
            scrub_options[:eager_loadables] = klass.get_eager_loadables_for_destroy + scrub_options[:additional_eager_loadables]
            klass.includes(scrub_options[:eager_loadables]).where(id: object_ids).each do |object|
              object.allow_scrubber_to_destroy = true
              object.destroy
            end
          end
        end
      end
    rescue => ex
      exception = ex
    ensure
      ActionMailer::Base.perform_deliveries = initial_mail_config
      Delayed::Worker.delay_jobs = initial_dj_config
      raise exception if exception.present?
    end
  end

  def initialize_scrub_options(scrub_options)
    [:assoc_objects_for_deletion, :assoc_scrubbers, :additional_eager_loadables].each { |key| scrub_options[key] ||= [] }
  end

  def scrub_translations_and_versions(klass, object_ids, scrub_options)
    if klass.respond_to?(:translation_class)
      column = klass.translation_class.reflections['globalized_model'].foreign_key
      klass.translation_class.where(column.to_sym => object_ids).delete_all
    end
    if klass.paper_trail.enabled?
      ChronusVersion.where(item_type: klass.name, item_id: object_ids).delete_all
    end
  end

  def scrub_article_publications(publication_ids)
    scrub(Article::Publication, publication_ids, {
      assoc_objects_for_deletion: [
        [JobLog, loggable_object_id: publication_ids, loggable_object_type: Article::Publication.name]
      ],
      assoc_scrubbers: [
        [:scrub_comments, Comment.where(article_publication_id: publication_ids)]
      ]
    })
  end

  def scrub_article_contents(article_content_ids)
    scrub(ArticleContent, article_content_ids, {
      assoc_objects_for_deletion: [
        [ArticleListItem, article_content_id: article_content_ids],
        [VulnerableContentLog, ref_obj_id: article_content_ids, ref_obj_type: ArticleContent.name]
      ],
      assoc_scrubbers: [
        [:scrub_taggings, ActsAsTaggableOn::Tagging.where(taggable_id: article_content_ids, taggable_type: ArticleContent.name)]
      ]
    })
  end

  def scrub_comments(comment_ids)
    scrub(Comment, comment_ids, {
      assoc_objects_for_deletion: [
        [Flag, content_type: Comment.name, content_id: comment_ids]
      ],
      assoc_scrubbers: [
        [:scrub_recent_activities, RecentActivity.where(ref_obj_id: comment_ids, ref_obj_type: Comment.name)]
      ]
    })
  end

  def scrub_posts(post_ids = @program.post_ids)
    scrub(Post, post_ids, {
      assoc_objects_for_deletion: [
        [JobLog, loggable_object_id: post_ids, loggable_object_type: Post.name],
        [VulnerableContentLog, ref_obj_id: post_ids, ref_obj_type: Post.name],
        [Flag, content_type: Post.name, content_id: post_ids],
        [PendingNotification, ref_obj_id: post_ids, ref_obj_type: Post.name]
      ],
      assoc_scrubbers: [
        [:scrub_recent_activities, RecentActivity.where(ref_obj_id: post_ids, ref_obj_type: Post.name)]
      ]
    })
  end

  def scrub_campaign_emails(cm_email_ids)
    scrub(CampaignManagement::CampaignEmail, cm_email_ids, {
      assoc_objects_for_deletion: [
        [CampaignManagement::EmailEventLog, message_id: cm_email_ids, message_type: CampaignManagement::CampaignEmail]
      ]
    })
  end

  def scrub_taggings(tagging_ids)
    scrub(ActsAsTaggableOn::Tagging, tagging_ids)
  end
end