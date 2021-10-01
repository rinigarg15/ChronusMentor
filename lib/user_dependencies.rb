module UserDependencies

  def self.included(base)
    base.extend IncludeDependencies
  end

  module IncludeDependencies
    def include_user_dependencies

      has_many  :connection_memberships,
                :class_name => "Connection::Membership",
                :dependent => :destroy

      has_many  :completed_mentoring_model_tasks,
                :class_name => 'MentoringModel::Task',
                foreign_key: "completed_by"

      has_many  :connection_mentor_memberships,
                :class_name => "Connection::MentorMembership"

      has_many  :connection_mentee_memberships,
                :class_name => "Connection::MenteeMembership"

      has_many  :groups,
                :through => :connection_memberships,
                :class_name => "Group"

      has_many  :mentoring_model_tasks,
                :through => :connection_memberships,
                :class_name => "MentoringModel::Task"

      has_many  :last_closed_group,
                -> { order('closed_at DESC').where("groups.status = ?", Group::Status::CLOSED).limit(1)},
                through: :connection_memberships,
                class_name: "Group",
                source: :group

      has_many  :active_groups,
                -> {where("groups.status NOT IN (?)", Group::Status::NOT_ACTIVE_CRITERIA)},
                :through => :connection_memberships,
                :class_name => "Group",
                :source => :group

      has_many  :closed_groups,
                -> {where("groups.status = '?'", Group::Status::CLOSED)},
                :through => :connection_memberships,
                :class_name => "Group",
                :source => :group

      has_many  :drafted_groups,
                -> {where("groups.status = '?'", Group::Status::DRAFTED)},
                :through => :connection_memberships,
                :class_name => "Group",
                :source => :group

      has_many  :owned_groups,
                -> {where(connection_memberships: {owner: true})},
                :through => :connection_memberships,
                :class_name => "Group",
                :source => :group

      has_many  :mentoring_groups,
                :through => :connection_mentor_memberships,
                :class_name => "Group",
                :source => :group

      has_many  :studying_groups,
                :through => :connection_mentee_memberships,
                :class_name => "Group",
                :source => :group

      has_many :tasks, :through => :connection_memberships

      has_many :private_notes,
               :through => :connection_memberships,
               :class_name => "Connection::PrivateNote"

      # Feedbacks given by the user
      has_many  :feedback_responses,
                :class_name => "Feedback::Response",
                :dependent => :destroy

      has_many :subscriptions, :dependent => :destroy
      has_many :subscribed_forums,
               :through => :subscriptions,
               :source => :ref_obj,
               :source_type => 'Forum'

      has_many :user_favorites, -> {where("type IS NULL AND mentor_request_id IS NULL").order('position')}, :dependent => :destroy
      has_many :favorites, -> { order 'position'}, :through => :user_favorites

      # The being_favorites has_many was introduced to destroy the corresponding user_favorites when a user is destroyed.
      has_many :being_favorites, :class_name => 'UserFavorite', :foreign_key => 'favorite_id', :dependent => :destroy

      has_many :sent_mentor_requests, :class_name => "MentorRequest", :foreign_key => 'sender_id', :dependent => :destroy
      has_many :received_mentor_requests, :class_name => "MentorRequest", :foreign_key => 'receiver_id', :dependent => :destroy
      has_many :pending_sent_mentor_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::NOT_ANSWERED)}, :class_name => "MentorRequest", :foreign_key => 'sender_id', :dependent => :destroy
      has_many :pending_received_mentor_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::NOT_ANSWERED)}, :class_name => "MentorRequest", :foreign_key => 'receiver_id', :dependent => :destroy
      has_many :rejected_received_mentor_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::REJECTED)}, :class_name => "MentorRequest", :foreign_key => 'receiver_id', :dependent => :destroy
      has_many :closed_received_mentor_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::CLOSED)}, :class_name => "MentorRequest", :foreign_key => 'receiver_id', :dependent => :destroy

      has_many :sent_project_requests, :class_name => "ProjectRequest", :foreign_key => 'sender_id', :dependent => :destroy
      has_many :received_project_requests, :class_name => "ProjectRequest", :foreign_key => 'receiver_id', :dependent => :destroy

      has_many :sent_meeting_requests, :class_name => "MeetingRequest", :foreign_key => 'sender_id', :dependent => :destroy
      has_many :received_meeting_requests, :class_name => "MeetingRequest", :foreign_key => 'receiver_id', :dependent => :destroy
      has_many :pending_sent_meeting_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::NOT_ANSWERED)}, :class_name => "MeetingRequest", :foreign_key => 'sender_id', :dependent => :destroy
      has_many :pending_received_meeting_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::NOT_ANSWERED)}, :class_name => "MeetingRequest", :foreign_key => 'receiver_id', :dependent => :destroy
      has_many :accepted_sent_meeting_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::ACCEPTED)}, :class_name => "MeetingRequest", :foreign_key => 'sender_id', :dependent => :destroy
      has_many :accepted_received_meeting_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::ACCEPTED)}, :class_name => "MeetingRequest", :foreign_key => 'receiver_id', :dependent => :destroy
      has_many :rejected_received_meeting_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::REJECTED)}, :class_name => "MeetingRequest", :foreign_key => 'receiver_id', :dependent => :destroy
      has_many :closed_received_meeting_requests, -> {where("mentor_requests.status = ?", AbstractRequest::Status::CLOSED)}, :class_name => "MeetingRequest", :foreign_key => 'receiver_id', :dependent => :destroy

      has_many :sent_mentor_offers, :class_name => "MentorOffer", :foreign_key => 'mentor_id', :dependent => :destroy
      has_many :received_mentor_offers, :class_name => "MentorOffer", :foreign_key => 'student_id', :dependent => :destroy
      has_many :pending_received_mentor_offers, -> { where(status: MentorOffer::Status::PENDING) }, class_name: "MentorOffer", foreign_key: 'student_id', dependent: :destroy

      has_many :pending_notifications, :as => :ref_obj_creator, :dependent => :destroy
      has_many :pending_notification_references, as: :ref_obj, class_name: "PendingNotification", dependent: :destroy

      has_many :ratings, -> { where(rateable_type: ["QaQuestion", "QaAnswer"]) }, :dependent => :destroy
      has_many :one_time_flags, :as => :ref_obj, :dependent => :destroy

      # Destroying parent posts destroys the corresponding children nodes through ancestry gem. This dependency is needed to break the recursion 
      # that happens when a parent post is the last post in a topic (which triggers a destroy on the topic) 
      has_many  :parent_posts, -> { where("ancestry is NULL") }, :class_name => "Post", :dependent => :destroy
      has_many  :posts, :dependent => :destroy
      has_many  :topics, :dependent => :destroy

      has_many  :qa_questions, :dependent => :destroy
      has_many	:qa_answers, :dependent => :destroy
      has_many	:answered_qa_questions,
                -> { distinct },
                :through => :qa_answers,
                :source => :qa_question

      has_many :confidentiality_audit_logs, -> { order 'id DESC'}, :dependent => :destroy

      has_many :state_transitions, dependent: :destroy, class_name: UserStateChange.name
      has_many :connection_membership_state_changes, dependent: :destroy, class_name: ConnectionMembershipStateChange.name

      #-------------------------------------------------------------------------
      # PROFILE RELATED
      #-------------------------------------------------------------------------

      has_many :profile_answers, :through => :member
      has_many :profile_views, dependent: :destroy, inverse_of: :user
      has_many :viewed_profile_views, dependent: :destroy, class_name: ProfileView.name, foreign_key: :viewed_by_id, inverse_of: :viewed_by

      ############# Below are used only for user destroy ###########################

      has_many :recent_activities, :as => :ref_obj, :dependent => :destroy

      # Group Related
      has_many :scraps, :through => :connection_memberships

      has_many :survey_answers, :dependent => :destroy

      # Email logs
      has_many :facilitation_delivery_logs, :dependent => :destroy

      #Articles related
      has_many :comments, :dependent => :destroy

      has_many :announcements, :dependent => :destroy
      has_many :accepted_rejected_membership_requests, :foreign_key => "admin_id", :dependent => :destroy, :class_name => "MembershipRequest"

      # All request favorite instances where the user is a favorite
      has_many :favorited_requests, :foreign_key => 'favorite_id', :class_name => "RequestFavorite", :dependent => :destroy
      has_many :activity_logs

      has_one :first_activity, -> {where(activity: ActivityLog::Activity::PROGRAM_VISIT)} , class_name: "ActivityLog"

      has_many  :flags, dependent: :destroy

      has_many :event_invites, dependent: :destroy
      has_many :program_events, through: :event_invites

      has_one :user_setting, dependent: :destroy

      has_many :job_logs, as: :ref_obj, dependent: :destroy

      has_many :program_event_users, dependent: :destroy
      has_many :dismissed_rollout_emails, :class_name => "RolloutEmail", :as => :ref_obj, :dependent => :destroy

      has_one :mentor_recommendation, :foreign_key => 'receiver_id', dependent: :destroy
      has_one :published_mentor_recommendation,
              -> {where("mentor_recommendations.status = ?", MentorRecommendation::Status::PUBLISHED)},
              class_name: "MentorRecommendation",
              foreign_key: 'receiver_id'
      has_many :recommendation_preferences, dependent: :destroy
      has_many :user_activities
      has_many :sent_mentor_recommendations, foreign_key: 'sender_id', class_name: "MentorRecommendation"
      has_many :initiated_pending_notifications, foreign_key: "initiator_id", class_name: "PendingNotification"

      # skip and mark mentor profiles favorite
      has_many :favorite_preferences, foreign_key: 'preference_marker_user_id', dependent: :destroy
      has_many :favorite_users,
                 :through => :favorite_preferences,
                 :source => :preference_marked_user
      has_many :mentee_marked_favorite_preferences, class_name: 'FavoritePreference', foreign_key: 'preference_marked_user_id', dependent: :destroy

      has_many :ignore_preferences, foreign_key: 'preference_marker_user_id', dependent: :destroy
      has_many :ignored_users,
                 :through => :ignore_preferences,
                 :source => :preference_marked_user
      has_many :mentee_marked_ignore_preferences, class_name: 'IgnorePreference', foreign_key: 'preference_marked_user_id', dependent: :destroy

      has_many :preference_based_mentor_lists, dependent: :destroy
    end
  end
end
