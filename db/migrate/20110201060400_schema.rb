class Schema< ActiveRecord::Migration[4.2]
  def change
    self.verbose = false
    create_table "abstract_message_receivers", :force => true do |t|
      t.integer  "member_id"
      t.integer  "message_id",                :null => false
      t.string   "name"
      t.string   "email"
      t.integer  "status",     :default => 0
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "abstract_message_receivers", ["member_id", "status"], :name => "index_abstract_message_receivers_on_member_id_and_status"
    add_index "abstract_message_receivers", ["member_id"], :name => "index_abstract_message_receivers_on_member_id"
    add_index "abstract_message_receivers", ["message_id"], :name => "index_abstract_message_receivers_on_message_id"

    create_table "activity_logs", :force => true do |t|
      t.integer  "user_id"
      t.integer  "program_id"
      t.integer  "role"
      t.integer  "activity"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "announcements", :force => true do |t|
      t.string   "title"
      t.text     "body",                    :limit => 2147483647
      t.integer  "program_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "attachment_file_name"
      t.string   "attachment_content_type"
      t.integer  "attachment_file_size"
      t.datetime "attachment_updated_at"
      t.integer  "user_id",                                       :null => false
      t.datetime "expiration_date"
    end

    add_index "announcements", ["program_id"], :name => "index_announcements_on_program_id"

    create_table "article_contents", :force => true do |t|
      t.string   "title"
      t.text     "body",                    :limit => 2147483647
      t.string   "type"
      t.text     "embed_code"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "status"
      t.datetime "published_at"
      t.string   "attachment_file_name"
      t.string   "attachment_content_type"
      t.integer  "attachment_file_size"
      t.datetime "attachment_updated_at"
    end

    create_table "article_list_items", :force => true do |t|
      t.string   "type"
      t.text     "content"
      t.text     "description"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "article_content_id"
    end

    create_table "article_publications", :force => true do |t|
      t.integer  "article_id", :null => false
      t.integer  "program_id", :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "article_publications", ["article_id"], :name => "index_article_publications_on_article_id"
    add_index "article_publications", ["program_id"], :name => "index_article_publications_on_program_id"

    create_table "articles", :force => true do |t|
      t.integer  "view_count",         :default => 0
      t.integer  "helpful_count",      :default => 0
      t.integer  "author_id"
      t.integer  "organization_id"
      t.boolean  "delta"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "article_content_id"
    end

    create_table "assistant_invitations", :force => true do |t| 
      t.integer  "user_id"
      t.string   "sent_to"
      t.string   "code"
      t.datetime "created_at"
      t.datetime "redeemed_at"
      t.datetime "expires_on"
    end

    create_table "assistants", :force => true do |t|
      t.integer  "member_id"
      t.integer  "user_id"
      t.integer  "notification_setting", :default => 3
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "auth_configs", :force => true do |t|
      t.integer  "organization_id",  :null => false
      t.string   "auth_type",        :null => false
      t.text     "config"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "title"
      t.text     "password_message"
      t.text     "regex_string"
    end

    add_index "auth_configs", ["organization_id"], :name => "index_auth_configs_on_organization_id"

    create_table "brands", :force => true do |t|
      t.string   "label",          :null => false
      t.string   "url",            :null => false
      t.string   "delivery_email", :null => false
      t.string   "reply_to_email"
      t.string   "feedback_email", :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "favicon"
    end

    create_table "ckeditor_assets", :force => true do |t|
      t.string   "data_file_name",                                 :null => false
      t.string   "data_content_type"
      t.integer  "data_file_size"
      t.integer  "assetable_id"
      t.string   "assetable_type",    :limit => 30
      t.string   "type",              :limit => 25
      t.string   "guid",              :limit => 10
      t.integer  "locale",            :limit => 1,  :default => 0
      t.integer  "user_id"
      t.integer  "program_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "ckeditor_assets", ["assetable_type", "assetable_id"], :name => "fk_assetable"
    add_index "ckeditor_assets", ["assetable_type", "type", "assetable_id"], :name => "idx_assetable_type"
    add_index "ckeditor_assets", ["program_id"], :name => "fk_program"
    add_index "ckeditor_assets", ["user_id"], :name => "fk_user"

    create_table "comments", :force => true do |t|
      t.integer  "article_publication_id"
      t.integer  "user_id"
      t.text     "body"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "committee_responses", :force => true do |t|
      t.integer  "membership_request_id"
      t.integer  "committee_member_id"
      t.text     "text"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "common_answers", :force => true do |t|
      t.integer  "user_id"
      t.integer  "common_question_id"
      t.text     "answer_text"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "type", limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "attachment_file_name"
      t.string   "attachment_content_type"
      t.integer  "attachment_file_size"
      t.datetime "attachment_updated_at"
      t.integer  "membership_request_id"
      t.integer  "feedback_response_id"
      t.integer  "group_id"
      t.integer  "location_id"
    end

    add_index "common_answers", ["common_question_id"], :name => "index_common_answers_on_common_question_id"
    add_index "common_answers", ["feedback_response_id"], :name => "index_common_answers_on_feedback_response_id"
    add_index "common_answers", ["group_id"], :name => "index_common_answers_on_group_id"
    add_index "common_answers", ["user_id"], :name => "index_common_answers_on_user_id"

    create_table "common_questions", :force => true do |t|
      t.integer  "program_id"
      t.text     "question_text"
      t.integer  "question_type"
      t.text     "question_info"
      t.integer  "position"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "section_id"
      t.boolean  "matchable",            :default => false, :null => false
      t.boolean  "required",             :default => false, :null => false
      t.text     "help_text"
      t.string   "type", limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "survey_id"
      t.integer  "common_answers_count", :default => 0
      t.integer  "private",              :default => 0
      t.boolean  "filterable",           :default => true
      t.integer  "feedback_form_id"
    end

    add_index "common_questions", ["common_answers_count"], :name => "index_common_questions_on_common_answers_count"
    add_index "common_questions", ["feedback_form_id"], :name => "index_common_questions_on_feedback_form_id"
    add_index "common_questions", ["program_id", "type", "position"], :name => "index_common_questions_on_program_id_and_type_and_position"

    create_table "common_tasks", :force => true do |t|
      t.text     "title"
      t.integer  "user_id"
      t.integer  "program_id"
      t.integer  "due_date_period"
      t.date     "due_date"
      t.boolean  "include_all_connections",    :default => true
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.boolean  "include_future_connections", :default => false
    end

    create_table "confidentiality_audit_logs", :force => true do |t|
      t.integer  "user_id"
      t.integer  "group_id"
      t.text     "reason"
      t.integer  "program_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "connection_activities", :force => true do |t|
      t.integer  "group_id",           :null => false
      t.integer  "recent_activity_id", :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "connection_activities", ["group_id"], :name => "index_connection_activities_on_group_id"

    create_table "connection_memberships", :force => true do |t|
      t.integer  "group_id",                             :null => false
      t.integer  "user_id",                              :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "status",                :default => 0, :null => false
      t.string   "type"
      t.datetime "last_status_update_at"
      t.string   "api_token", limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "connection_memberships", ["api_token"], :name => "index_connection_memberships_on_api_token"
    add_index "connection_memberships", ["group_id"], :name => "index_group_students_on_group_id"
    add_index "connection_memberships", ["user_id"], :name => "index_group_students_on_student_id"

    create_table "connection_milestones", :force => true do |t|
      t.integer  "template_milestone_id"
      t.integer  "group_id"
      t.date     "start_date"
      t.date     "completed_date"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "connection_milestones", ["group_id"], :name => "index_connection_milestones_on_group_id"

    create_table "connection_private_notes", :force => true do |t|
      t.integer  "connection_membership_id", :null => false
      t.text     "text"
      t.string   "attachment_file_name"
      t.string   "attachment_content_type"
      t.integer  "attachment_file_size"
      t.datetime "attachment_updated_at"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "connection_private_notes", ["connection_membership_id"], :name => "index_connection_private_notes_on_connection_membership_id"
    add_index "connection_private_notes", ["created_at"], :name => "index_connection_private_notes_on_created_at"

    create_table "connection_tasks", :force => true do |t|
      t.integer  "template_task_id"
      t.integer  "milestone_id"
      t.integer  "owner_id"
      t.integer  "status",           :default => 1
      t.date     "due_date"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "connection_tasks", ["milestone_id"], :name => "index_connection_tasks_on_milestone_id"

    create_table "delayed_jobs", :force => true do |t|
      t.integer  "priority",                         :default => 0
      t.integer  "attempts",                         :default => 0
      t.text     "handler",    :limit => 2147483647
      t.text     "last_error"
      t.datetime "run_at"
      t.datetime "locked_at"
      t.datetime "failed_at"
      t.string   "locked_by"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "educations", :force => true do |t|
      t.string   "school_name", limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "degree", limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "major", limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "graduation_year"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "user_answer_id"
      t.integer  "profile_answer_id", :null => false
    end

    add_index "educations", ["degree"], :name => "index_educations_on_degree"
    add_index "educations", ["major"], :name => "index_educations_on_major"
    add_index "educations", ["profile_answer_id"], :name => "index_educations_on_profile_answer_id"
    add_index "educations", ["school_name"], :name => "index_educations_on_school_name"
    add_index "educations", ["user_answer_id"], :name => "index_educations_on_user_answer_id"

    create_table "email_trackers", :force => true do |t|
      t.string   "class_name", :null => false
      t.integer  "content_id"
      t.integer  "user_id"
      t.integer  "program_id"
      t.datetime "opened_at"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "type",       :null => false
    end

    create_table "experiences", :force => true do |t|
      t.string   "job_title", limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "start_year"
      t.integer  "end_year"
      t.string   "company", limit: UTF8MB4_VARCHAR_LIMIT
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "start_month",       :default => 0
      t.integer  "end_month",         :default => 0
      t.boolean  "current_job",       :default => false
      t.integer  "user_answer_id"
      t.integer  "profile_answer_id",                    :null => false
    end

    add_index "experiences", ["company"], :name => "index_experiences_on_company"
    add_index "experiences", ["job_title"], :name => "index_experiences_on_job_title"
    add_index "experiences", ["profile_answer_id"], :name => "index_experiences_on_profile_answer_id"
    add_index "experiences", ["user_answer_id"], :name => "index_experiences_on_user_answer_id"

    create_table "facilitation_delivery_logs", :force => true do |t|
      t.integer  "facilitation_message_id"
      t.integer  "user_id"
      t.datetime "last_delivered_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "facilitation_messages", :force => true do |t|
      t.string   "subject"
      t.text     "message",    :limit => 2147483647
      t.integer  "send_on"
      t.integer  "program_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.boolean  "enabled",                          :default => true
    end

    create_table "features", :force => true do |t|
      t.string "name"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "feedback_forms", :force => true do |t|
      t.integer  "program_id", :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "feedback_forms", ["program_id"], :name => "index_feedback_forms_on_program_id"

    create_table "feedback_responses", :force => true do |t|
      t.integer  "feedback_form_id", :null => false
      t.integer  "group_id",         :null => false
      t.integer  "user_id",          :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "feedback_responses", ["feedback_form_id"], :name => "index_feedback_responses_on_feedback_form_id"
    add_index "feedback_responses", ["group_id"], :name => "index_feedback_responses_on_group_id"
    add_index "feedback_responses", ["user_id"], :name => "index_feedback_responses_on_user_id"

    create_table "feedbacks", :force => true do |t|
      t.integer  "member_id",  :null => false
      t.integer  "program_id"
      t.string   "subject"
      t.text     "comment",    :null => false
      t.text     "url"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "forums", :force => true do |t|
      t.integer "program_id"
      t.text    "description"
      t.integer "topics_count", :default => 0
      t.string  "name"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "four_oh_fours", :force => true do |t|
      t.string   "host"
      t.string   "path"
      t.string   "referer"
      t.string   "ip"
      t.text     "user_agent"
      t.integer  "count",      :default => 0
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "four_oh_fours", ["path", "referer", "ip"], :name => "index_four_oh_fours_on_path_and_referer_and_ip"
    add_index "four_oh_fours", ["updated_at"], :name => "index_four_oh_fours_on_updated_at"

    create_table "groups", :force => true do |t|
      t.integer  "program_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "status",                  :default => 0
      t.text     "termination_reason"
      t.integer  "admin_id"
      t.datetime "closed_at"
      t.integer  "activity_count",          :default => 0
      t.datetime "expiry_time"
      t.integer  "termination_mode"
      t.datetime "last_activity_at"
      t.string   "logo_file_name"
      t.string   "logo_content_type"
      t.string   "name", limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "logo_file_size"
      t.datetime "logo_updated_at"
      t.boolean  "global",                  :default => false
      t.boolean  "delta",                   :default => false
      t.datetime "last_member_activity_at"
      t.integer  "mentoring_template_id"
    end

    add_index "groups", ["global"], :name => "index_groups_on_global"
    add_index "groups", ["last_activity_at"], :name => "index_groups_on_last_activity_at"
    add_index "groups", ["last_member_activity_at"], :name => "index_groups_on_last_member_activity_at"
    add_index "groups", ["name"], :name => "index_groups_on_name"

    create_table "handbooks", :force => true do |t|
      t.string   "attachment_file_name"
      t.string   "attachment_content_type"
      t.integer  "attachment_file_size"
      t.datetime "attachment_updated_at"
      t.integer  "program_id"
      t.boolean  "default"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.boolean  "enabled",                 :default => true
    end

    create_table "instructions", :force => true do |t|
      t.integer  "program_id", :null => false
      t.text     "content"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "type",       :null => false
    end

    create_table "locations", :force => true do |t|
      t.string  "city", limit: UTF8MB4_VARCHAR_LIMIT
      t.string  "state", limit: UTF8MB4_VARCHAR_LIMIT
      t.string  "country", limit: UTF8MB4_VARCHAR_LIMIT
      t.float   "lat"
      t.float   "lng"
      t.string  "full_address", limit: UTF8MB4_VARCHAR_LIMIT
      t.boolean "reliable",              :default => false
      t.integer "user_answers_count",    :default => 0
      t.integer "profile_answers_count", :default => 0
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "locations", ["full_address"], :name => "index_locations_on_full_address"
    add_index "locations", ["profile_answers_count"], :name => "index_locations_on_profile_answers_count"
    add_index "locations", ["user_answers_count"], :name => "index_locations_on_user_answers_count"

    create_table "mailer_templates", :force => true do |t|
      t.integer  "program_id",                   :null => false
      t.string   "uid",                          :null => false
      t.boolean  "enabled",    :default => true
      t.text     "source"
      t.text     "subject"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "mailer_widgets", :force => true do |t|
      t.integer  "program_id", :null => false
      t.string   "uid",        :null => false
      t.text     "source"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "match_configs", :force => true do |t|
      t.integer  "mentor_question_id"
      t.integer  "student_question_id"
      t.integer  "program_id"
      t.float    "weight",              :default => 1.0, :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "match_configs", ["program_id"], :name => "index_match_configs_on_program_id"

    create_table "meeting_feedbacks", :force => true do |t|
      t.integer  "member_meeting_id"
      t.text     "body"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "meeting_feedbacks", ["member_meeting_id"], :name => "index_meeting_feedbacks_on_member_meeting_id"

    create_table "meetings", :force => true do |t|
      t.integer  "group_id"
      t.text     "description"
      t.string   "topic"
      t.datetime "start_time"
      t.datetime "end_time"
      t.text     "location"
      t.integer  "owner_id",                        :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "program_id",                      :null => false
      t.boolean  "delta",        :default => false
      t.integer  "ics_sequence", :default => 0
    end

    add_index "meetings", ["group_id"], :name => "index_meetings_on_group_id"
    add_index "meetings", ["program_id"], :name => "index_meetings_on_program_id"
    add_index "meetings", ["start_time"], :name => "index_meetings_on_start_time"

    create_table "member_meetings", :force => true do |t|
      t.integer  "member_id",                                :null => false
      t.integer  "meeting_id",                               :null => false
      t.boolean  "attending",             :default => true
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.datetime "reminder_time"
      t.boolean  "reminder_sent",         :default => false
      t.boolean  "feedback_request_sent", :default => false
    end

    add_index "member_meetings", ["attending"], :name => "index_member_meetings_on_attending"
    add_index "member_meetings", ["member_id", "meeting_id"], :name => "index_member_meetings_on_member_id_and_meeting_id"

    create_table "member_notifications", :force => true do |t|
      t.integer  "member_id"
      t.integer  "actor_id"
      t.integer  "organization_id"
      t.integer  "object_id"
      t.string   "object_type"
      t.integer  "action"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "members", :force => true do |t|
      t.integer  "organization_id",                                             :null => false
      t.boolean  "admin",                                    :default => false
      t.integer  "state",                                    :default => 0,     :null => false
      t.integer  "notification_setting",                     :default => 0
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.boolean  "external_user"
      t.string   "login_name", limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "linkedin_url"
      t.string   "email",                     :limit => 100,                    :null => false
      t.string   "crypted_password",          :limit => 40
      t.string   "remember_token",            :limit => 40
      t.datetime "remember_token_expires_at"
      t.string   "salt",                      :limit => 40
      t.string   "time_zone"
      t.string   "first_name"
      t.string   "last_name"
      t.integer  "auth_config_id"
      t.string   "api_key", limit: UTF8MB4_VARCHAR_LIMIT,    :default => ""
      t.boolean  "gp_alert_recieved",                        :default => false
      t.string   "calendar_api_key", limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "members", ["api_key", "organization_id"], :name => "index_members_on_api_key_and_organization_id"
    add_index "members", ["calendar_api_key", "organization_id"], :name => "index_members_on_calendar_api_key_and_organization_id"
    add_index "members", ["email"], :name => "index_members_on_email"
    add_index "members", ["login_name"], :name => "index_members_on_login_name"
    add_index "members", ["organization_id"], :name => "index_members_on_chronus_user_id_and_organization_id"

    create_table "membership_requests", :force => true do |t|
      t.string   "name"
      t.string   "email"
      t.integer  "program_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "status",           :limit => 2, :default => 0
      t.text     "response_text"
      t.integer  "user_id"
      t.datetime "deleted_at"
      t.string   "accepted_as"
      t.boolean  "external_user",                 :default => false
      t.string   "response_subject"
      t.string   "gc_resolution"
      t.integer  "resolver_id"
      t.datetime "resolved_at"
      t.integer  "location_id"
    end

    add_index "membership_requests", ["program_id", "status", "created_at"], :name => "index_mem_req_on_prog_id_status_created_at"

    create_table "mentor_offers", :force => true do |t|
      t.integer  "program_id"
      t.integer  "mentor_id"
      t.integer  "student_id"
      t.integer  "group_id"
      t.text     "message"
      t.text     "response"
      t.integer  "status"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "mentor_offers", ["mentor_id", "status"], :name => "index_mentor_offers_on_mentor_id_and_status"
    add_index "mentor_offers", ["student_id", "status"], :name => "index_mentor_offers_on_student_id_and_status"

    create_table "mentor_requests", :force => true do |t|
      t.integer  "program_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "status",              :default => 0
      t.integer  "student_id"
      t.integer  "mentor_id"
      t.text     "message"
      t.text     "response_text"
      t.integer  "group_id"
      t.integer  "forwarded_mentor_id"
      t.boolean  "show_in_profile",     :default => true
    end

    add_index "mentor_requests", ["forwarded_mentor_id"], :name => "index_mentor_requests_on_forwarded_mentor_id"
    add_index "mentor_requests", ["program_id", "status"], :name => "index_mentor_requests_on_program_id_and_status"

    create_table "mentoring_slots", :force => true do |t|
      t.datetime "start_time"
      t.datetime "end_time"
      t.text     "location"
      t.integer  "repeats"
      t.integer  "member_id",                               :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.date     "repeats_end_date"
      t.string   "repeats_on_week"
      t.boolean  "repeats_by_month_date", :default => true
    end

    add_index "mentoring_slots", ["member_id"], :name => "index_mentoring_slots_on_member_id"

    create_table "mentoring_template_milestones", :force => true do |t|
      t.integer  "mentoring_template_id"
      t.string   "title"
      t.text     "description"
      t.integer  "duration"
      t.integer  "position"
      t.text     "resources"
      t.boolean  "draft",                    :default => true
      t.integer  "connection_membership_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "mentoring_template_milestones", ["mentoring_template_id"], :name => "index_mentoring_template_milestones_on_mentoring_template_id"

    create_table "mentoring_template_tasks", :force => true do |t|
      t.integer  "milestone_id"
      t.string   "title"
      t.integer  "role_id"
      t.integer  "connection_membership_id"
      t.text     "description"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "mentoring_template_tasks", ["milestone_id"], :name => "index_mentoring_template_tasks_on_milestone_id"

    create_table "mentoring_templates", :force => true do |t|
      t.integer  "program_id"
      t.string   "title"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "mentoring_templates", ["program_id"], :name => "index_mentoring_templates_on_program_id"

    create_table "mentoring_tips", :force => true do |t|
      t.text     "message"
      t.boolean  "enabled",    :default => true
      t.integer  "program_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "messages", :force => true do |t|
      t.integer  "program_id"
      t.integer  "sender_id"
      t.string   "sender_name"
      t.string   "sender_email"
      t.string   "subject"
      t.text     "content"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "group_id"
      t.integer  "parent_id"
      t.string   "type", limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "messages", ["program_id", "type"], :name => "index_messages_on_program_id_and_type"
    add_index "messages", ["sender_id"], :name => "index_messages_on_sender_id"

    create_table "moderatorships", :force => true do |t|
      t.integer "forum_id"
      t.integer "user_id"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "moderatorships", ["forum_id"], :name => "index_moderatorships_on_forum_id"

    create_table "open_id_authentication_associations", :force => true do |t|
      t.integer "issued"
      t.integer "lifetime"
      t.string  "handle"
      t.string  "assoc_type"
      t.binary  "server_url"
      t.binary  "secret"
    end

    create_table "open_id_authentication_nonces", :force => true do |t|
      t.integer "timestamp",  :null => false
      t.string  "server_url"
      t.string  "salt",       :null => false
    end

    create_table "organization_features", :force => true do |t|
      t.integer "organization_id"
      t.integer "feature_id"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "organization_features", ["organization_id"], :name => "index_features_on_program_id"

    create_table "pages", :force => true do |t|
      t.integer  "program_id"
      t.string   "title"
      t.text     "content",    :limit => 2147483647
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "position"
    end

    create_table "passwords", :force => true do |t|
      t.string   "reset_code"
      t.datetime "expiration_date"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "member_id"
    end

    create_table "pending_notifications", :force => true do |t|
      t.integer  "user_id"
      t.integer  "program_id"
      t.integer  "ref_obj_id"
      t.string   "ref_obj_type"
      t.integer  "action_type"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "initiator_id"
    end

    create_table "permissions", :force => true do |t|
      t.string "name", limit: UTF8MB4_VARCHAR_LIMIT, :null => false
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "permissions", ["name"], :name => "index_permissions_on_name"

    create_table "photos", :force => true do |t|
      t.integer  "program_id"
      t.string   "picture_data_content_type"
      t.string   "picture_data_file_name"
      t.integer  "picture_data_file_size"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "posts", :force => true do |t|
      t.integer  "user_id"
      t.integer  "topic_id"
      t.text     "body",                    :limit => 2147483647
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "attachment_file_name"
      t.string   "attachment_content_type"
      t.integer  "attachment_file_size"
      t.datetime "attachment_updated_at"
      t.string   "ancestry", limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "posts", ["ancestry"], :name => "index_posts_on_ancestry"
    add_index "posts", ["created_at"], :name => "index_posts_on_forum_id"
    add_index "posts", ["topic_id", "created_at"], :name => "index_posts_on_topic_id"
    add_index "posts", ["user_id", "created_at"], :name => "index_posts_on_user_id"

    create_table "profile_answers", :force => true do |t|
      t.integer  "member_id"
      t.integer  "profile_question_id"
      t.string   "attachment_file_name"
      t.text     "answer_text"
      t.string   "attachment_content_type"
      t.integer  "attachment_file_size"
      t.datetime "attachment_updated_at"
      t.integer  "location_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "profile_answers", ["location_id"], :name => "index_profile_answers_on_location_id"
    add_index "profile_answers", ["member_id", "profile_question_id"], :name => "index_profile_answers_on_member_id_and_profile_question_id"

    create_table "profile_pictures", :force => true do |t|
      t.string   "image_file_name"
      t.string   "image_content_type"
      t.integer  "image_file_size"
      t.datetime "image_updated_at"
      t.string   "image_remote_url"
      t.integer  "member_id"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "profile_pictures", ["member_id"], :name => "index_profile_pictures_on_member_id"

    create_table "profile_questions", :force => true do |t|
      t.integer  "organization_id"
      t.text     "question_text"
      t.integer  "question_type"
      t.text     "question_info"
      t.integer  "position"
      t.integer  "section_id"
      t.string   "help_text"
      t.integer  "profile_answers_count", :default => 0
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "profile_questions", ["organization_id", "position"], :name => "index_profile_questions_on_organization_id_and_position"
    add_index "profile_questions", ["profile_answers_count"], :name => "index_profile_questions_on_profile_answers_count"
    add_index "profile_questions", ["section_id"], :name => "index_profile_questions_on_section_id"

    create_table "profile_summary_fields", :force => true do |t|
      t.integer  "common_question_id"
      t.integer  "default_question_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "program_id",          :null => false
    end

    create_table "program_activities", :force => true do |t|
      t.integer  "program_id",  :null => false
      t.integer  "activity_id", :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "program_activities", ["activity_id"], :name => "index_program_activities_on_activity_id"
    add_index "program_activities", ["program_id"], :name => "index_program_activities_on_program_id"

    create_table "program_invitations", :force => true do |t|
      t.integer  "user_id"
      t.string   "code", limit: UTF8MB4_VARCHAR_LIMIT
      t.datetime "created_at"
      t.datetime "redeemed_at"
      t.string   "sent_to"
      t.datetime "expires_on"
      t.integer  "program_id"
      t.integer  "use_count",   :default => 0
      t.text     "message"
      t.datetime "sent_on"
      t.boolean  "system",      :default => false
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "programs", :force => true do |t|
      t.string   "name"
      t.text     "description"
      t.string   "subdomain"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "logo_file_name"
      t.string   "logo_content_type"
      t.integer  "logo_file_size"
      t.datetime "logo_updated_at"
      t.string   "mentor_name"
      t.string   "mentee_name"
      t.integer  "user_id"
      t.boolean  "public_mentors_listing"
      t.boolean  "allow_one_to_many_mentoring"
      t.integer  "mentoring_period"
      t.boolean  "send_facilitation_messages",                                  :default => true
      t.text     "analytics_script"
      t.text     "agreement",                             :limit => 2147483647
      t.integer  "sort_users_by",                         :limit => 1,          :default => 0
      t.integer  "default_max_connections_limit",                               :default => 5
      t.integer  "min_preferred_mentors",                                       :default => 0
      t.boolean  "unconnected_mentee_can_contact_mentor",                       :default => true,                   :null => false
      t.integer  "max_connections_for_mentee"
      t.integer  "theme_id"
      t.boolean  "connection_requires_mentor_approval",                         :default => false
      t.boolean  "allow_mentoring_requests",                                    :default => true
      t.text     "allow_mentoring_requests_message"
      t.string   "admin_name",                                                  :default => "Administrator"
      t.integer  "inactivity_tracking_period",                                  :default => 2592000
      t.boolean  "auto_terminate",                                              :default => false
      t.integer  "mentor_request_style"
      t.boolean  "allow_membership_requests",                                   :default => true
      t.text     "footer_code"
      t.string   "domain"
      t.string   "type", limit: UTF8MB4_VARCHAR_LIMIT,                             :null => false
      t.integer  "parent_id"
      t.string   "program_term",                                                :default => "Program"
      t.string   "root", limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "brand_id"
      t.integer  "programs_count"
      t.string   "mentoring_connection_name",                                   :default => "Mentoring Connection"
      t.string   "gapp_domain"
      t.string   "logout_path"
      t.boolean  "ssl_only",                                                    :default => false
      t.boolean  "active",                                                      :default => true
      t.integer  "login_expiry_period",                                         :default => 120
      t.text     "privacy_policy"
      t.boolean  "default_profile_privacy",                                     :default => false
      t.string   "article_name",                                                :default => "Article"
      t.boolean  "mentor_offer_needs_acceptance",                               :default => false
      t.string   "roles_to_join_directly"
      t.integer  "base_program_id"
      t.integer  "subscription_type",                                           :default => 1
      t.integer  "email_theme",                                                 :default => 0
      t.boolean  "allow_end_user_milestones",                                   :default => false
    end

    add_index "programs", ["gapp_domain"], :name => "index_programs_on_gapp_domain"
    add_index "programs", ["type", "parent_id", "root"], :name => "index_programs_on_type_and_parent_id_and_root"
    add_index "programs", ["type", "subdomain", "domain"], :name => "index_programs_on_type_and_subdomain_and_domain"

    create_table "qa_answers", :force => true do |t|
      t.integer  "qa_question_id"
      t.integer  "user_id"
      t.text     "content"
      t.integer  "score",          :default => 0
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "qa_answers", ["qa_question_id"], :name => "index_qa_answers_on_qa_question_id"
    add_index "qa_answers", ["user_id"], :name => "index_qa_answers_on_user_id"

    create_table "qa_questions", :force => true do |t|
      t.integer  "program_id"
      t.integer  "user_id"
      t.text     "summary"
      t.text     "description"
      t.integer  "qa_answers_count", :default => 0
      t.integer  "views",            :default => 0
      t.boolean  "delta",            :default => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "qa_questions", ["program_id", "updated_at"], :name => "index_qa_questions_on_program_id_and_updated_at"

    create_table "ratings", :force => true do |t|
      t.integer  "rating",                      :default => 0
      t.string   "rateable_type", :limit => 15, :default => "", :null => false
      t.integer  "rateable_id",                 :default => 0,  :null => false
      t.integer  "user_id",                     :default => 0,  :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "ratings", ["user_id"], :name => "fk_ratings_user"

    create_table "recent_activities", :force => true do |t|
      t.integer  "member_id"
      t.integer  "ref_obj_id"
      t.string   "ref_obj_type"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "action_type",     :null => false
      t.integer  "for_id"
      t.integer  "target",          :null => false
      t.integer  "organization_id"
      t.text     "message"
    end

    add_index "recent_activities", ["action_type"], :name => "index_recent_activities_on_action_type"
    add_index "recent_activities", ["for_id"], :name => "index_recent_activities_on_for_id"
    add_index "recent_activities", ["member_id"], :name => "index_recent_activities_on_member_id"
    add_index "recent_activities", ["target"], :name => "index_recent_activities_on_target"

    create_table "rejection_logs", :force => true do |t|
      t.integer  "rejected_mentor_id"
      t.integer  "mentor_request_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "rejection_logs", ["mentor_request_id"], :name => "index_rejection_logs_on_mentor_request_id"

    create_table "resources", :force => true do |t|
      t.integer  "program_id", :null => false
      t.string   "title"
      t.text     "content"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "role_permissions", :force => true do |t|
      t.integer "role_id",       :null => false
      t.integer "permission_id", :null => false
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "role_permissions", ["permission_id"], :name => "index_role_permissions_on_permission_id"
    add_index "role_permissions", ["role_id"], :name => "index_role_permissions_on_role_id"

    create_table "role_questions", :force => true do |t|
      t.integer  "role_id"
      t.boolean  "required",            :default => false, :null => false
      t.integer  "private",             :default => 0
      t.boolean  "filterable",          :default => true
      t.integer  "profile_question_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.boolean  "in_summary",          :default => false
    end

    add_index "role_questions", ["profile_question_id"], :name => "index_role_questions_on_profile_question_id"
    add_index "role_questions", ["role_id"], :name => "index_role_questions_on_role_id"

    create_table "role_references", :force => true do |t|
      t.integer  "ref_obj_id",   :null => false
      t.string   "ref_obj_type", limit: UTF8MB4_VARCHAR_LIMIT,  :null => false
      t.integer  "role_id",      :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "role_references", ["ref_obj_id", "ref_obj_type"], :name => "index_role_references_on_ref_obj_id_and_ref_obj_type"
    add_index "role_references", ["role_id"], :name => "index_role_references_on_role_id"

    create_table "role_resources", :force => true do |t|
      t.integer  "role_id",     :null => false
      t.integer  "resource_id", :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "roles", :force => true do |t|
      t.string   "name", limit: UTF8MB4_VARCHAR_LIMIT,  :null => false
      t.integer  "program_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "roles", ["name"], :name => "index_roles_on_name"
    add_index "roles", ["program_id"], :name => "index_roles_on_program_id"

    create_table "scraps", :force => true do |t|
      t.text     "message"
      t.integer  "group_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "attachment_file_name"
      t.string   "attachment_content_type"
      t.integer  "attachment_file_size"
      t.datetime "attachment_updated_at"
      t.integer  "reply_within"
      t.boolean  "posted_via_email"
      t.integer  "connection_membership_id"
    end

    create_table "sections", :force => true do |t|
      t.integer "program_id"
      t.string  "title"
      t.integer "position"
      t.boolean "default_field"
      t.string  SOURCE_AUDIT_KEY,    :limit => UTF8MB4_VARCHAR_LIMIT
    end

    add_index "sections", ["program_id", "position"], :name => "index_sections_on_program_id_and_position"

    create_table "sessions", :force => true do |t|
      t.string   "session_id", limit: UTF8MB4_VARCHAR_LIMIT, :null => false
      t.text     "data"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
    add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

    create_table "simple_captcha_data", :force => true do |t|
      t.string   "key",        :limit => 40
      t.string   "value",      :limit => 6
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "subscriptions", :force => true do |t|
      t.integer  "user_id"
      t.integer  "ref_obj_id"
      t.string   "ref_obj_type", limit: UTF8MB4_VARCHAR_LIMIT
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "subscriptions", ["ref_obj_id"], :name => "index_subscriptions_on_ref_obj_id"
    add_index "subscriptions", ["ref_obj_type"], :name => "index_subscriptions_on_ref_obj_type"
    add_index "subscriptions", ["user_id"], :name => "index_subscriptions_on_user_id"

    create_table "surveys", :force => true do |t|
      t.integer  "program_id"
      t.string   "name"
      t.date     "due_date"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "taggings", :force => true do |t|
      t.integer  "tag_id"
      t.integer  "tagger_id"
      t.string   "tagger_type", limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "taggable_id"
      t.string   "taggable_type", limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "context", limit: UTF8MB4_VARCHAR_LIMIT
      t.datetime "created_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
    add_index "taggings", ["taggable_id", "taggable_type", "context"], :name => "index_taggings_on_taggable_id_and_taggable_type_and_context"

    create_table "tags", :force => true do |t|
      t.string "name", limit: UTF8MB4_VARCHAR_LIMIT
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "tasks", :force => true do |t|
      t.text     "description"
      t.date     "due_date",                                    :null => false
      t.integer  "group_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.string   "title",                                       :null => false
      t.boolean  "done",                     :default => false
      t.integer  "connection_membership_id"
      t.integer  "common_task_id"
    end

    add_index "tasks", ["due_date"], :name => "index_tasks_on_due_date"
    add_index "tasks", ["updated_at"], :name => "index_tasks_on_updated_at"

    create_table "themes", :force => true do |t|
      t.string   "css_file_name"
      t.string   "css_content_type"
      t.integer  "css_file_size"
      t.datetime "css_updated_at"
      t.integer  "program_id"
      t.string   "name"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    create_table "topics", :force => true do |t|
      t.integer  "forum_id"
      t.integer  "user_id"
      t.string   "title"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.integer  "hits",        :default => 0
      t.integer  "posts_count", :default => 0
    end

    add_index "topics", ["forum_id"], :name => "index_topics_on_forum_id"
    add_index "topics", ["forum_id"], :name => "index_topics_on_forum_id_and_replied_at"
    add_index "topics", ["forum_id"], :name => "index_topics_on_sticky_and_replied_at"

    create_table "user_contacts", :force => true do |t|
      t.integer  "user_id"
      t.string   "name"
      t.string   "email",      :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "user_contacts", ["user_id"], :name => "index_user_contacts_on_user_id"

    create_table "user_favorites", :force => true do |t|
      t.integer  "user_id",           :null => false
      t.integer  "favorite_id",       :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.text     "note"
      t.integer  "position"
      t.string   "type"
      t.integer  "mentor_request_id"
    end

    add_index "user_favorites", ["mentor_request_id"], :name => "index_user_favorites_on_mentor_request_id"

    create_table "users", :force => true do |t|
      t.string   "state",                        :default => "active", :null => false, limit: UTF8MB4_VARCHAR_LIMIT
      t.datetime "activated_at"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
      t.text     "admin_notes"
      t.integer  "program_id"
      t.datetime "last_seen_at"
      t.boolean  "delta",                        :default => false
      t.integer  "notification_setting",         :default => 0,        :null => false
      t.integer  "max_connections_limit"
      t.integer  "state_changer_id"
      t.text     "state_change_reason"
      t.integer  "qa_answers_count",             :default => 0
      t.datetime "last_weekly_update_sent_time"
      t.datetime "profile_updated_at"
      t.integer  "member_id",                                          :null => false
      t.integer  "membership_request_id"
      t.string   "badge_text"
      t.boolean  "private",                      :default => false
      t.boolean  "global",                       :default => false
      t.integer  "primary_home_tab",             :default => 0
    end

    add_index "users", ["created_at"], :name => "index_users_on_created_at"
    add_index "users", ["member_id", "global"], :name => "index_users_on_member_id_and_global"
    add_index "users", ["member_id", "program_id"], :name => "index_users_on_member_id_and_program_id"
    add_index "users", ["membership_request_id"], :name => "index_users_on_membership_request_id"
    add_index "users", ["state"], :name => "index_users_on_state"

    create_table "votes", :force => true do |t|
      t.boolean  "vote",          :default => false
      t.integer  "voteable_id",                      :null => false
      t.string   "voteable_type",                    :null => false
      t.integer  "voter_id"
      t.string   "voter_type"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   SOURCE_AUDIT_KEY,    limit: UTF8MB4_VARCHAR_LIMIT
    end

    add_index "votes", ["voteable_id", "voteable_type"], :name => "fk_voteables"
    add_index "votes", ["voter_id", "voter_type"], :name => "fk_voters"
    self.verbose = true
  end
end
