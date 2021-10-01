module SalesDemo
  class SalesDataScrapper
    attr_accessor :subdomain, :programs, :referer, :domain, :organization_url, :all_ck_assets, :exported_ck_assets
    DEFAULT_PROGRAMS = ["flash-mentoring", "onboarding", "career-mentoring-program", "coaching", "project-mentoring", "academic-mentoring", "circles"]
    DEFAULT_SUBDOMAIN = "newdemo"
    LOCATION = Rails.root + "demo/data/"
    ATTACHMENT_FOLDER = LOCATION + "attachments/"
    METADATA_FILE_PATH = LOCATION + "metadata.json"
    CKEDITOR_FOLDER = ATTACHMENT_FOLDER + "ckeditor/"
    DEFAULT_DOMAIN = "chronus.com"

    def initialize(options = {})
      self.subdomain = options[:subdomain] || DEFAULT_SUBDOMAIN
      self.programs = options[:programs] || DEFAULT_PROGRAMS
      self.domain = options[:domain] || DEFAULT_DOMAIN
      self.exported_ck_assets = []
      self.referer = {}
      FileUtils.rm_rf(Rails.root + 'demo/data.zip')
      SolutionPack.create_if_not_exist_with_permission(LOCATION, 0777)
      File.open(LOCATION + "extracted_date.txt", "wb"){|f| f.write(Time.now)}
      SolutionPack.create_if_not_exist_with_permission(ATTACHMENT_FOLDER, 0777)
      SolutionPack.create_if_not_exist_with_permission(CKEDITOR_FOLDER, 0777)
    end

    def scrap
      [:organization,
       :security_setting,
       :programs,
       :program_asset,
       :notification_settings,
       :organization_features,
       :solution_pack_settings,
       :organization_resources,
       :mentoring_model_templates,
       :membership_requests,
       :members,
       :users,
       :organization_admin_views,
       :profile_pictures,
       :profile_answers,
       :educations,
       :experiences,
       :publications,
       :managers,
       :user_settings,
       :groups,
       :object_role_permissions,
       :connection_memberships,
       :mentoring_model_milestones,
       :mentoring_model_goals,
       :mentoring_model_tasks,
       :goal_activities,
       :scraps,
       :scrap_receivers,
       :meeting_requests,
       :meetings,
       :member_meetings,
       :survey_answers,
       :answer_choices,
       :member_meeting_responses,
       :activity_logs,
       :group_checkins,
       :user_state_changes,
       :group_state_changes,
       :connection_membership_state_changes,
       :pages,
       :page_translations,
       :admin_messages,
       :admin_message_receivers,
       :campaign_message_analyticss,
       :program_invitations,
       :connection_activities,
       :recent_activities,
       :ckeditor_assets].each do |model|
        self.send("scrap_#{model}")
      end
      write_metadata
      create_zip_file
      # If possible we can upload it to s3
    end

    def scrap_organization
      organization = Program::Domain.get_organization(self.domain, self.subdomain)
      raise Exception.new("Organization not found") unless organization
      self.organization_url = organization.url
      self.referer[:organization] = organization.id
      self.all_ck_assets = Ckeditor::Asset.where(program_id: self.referer[:organization])
      dump_data(organization, "Organization")
      export_ck_assets_related_content([organization], [:browser_warning, :privacy_policy, :agreement])
    end

    def scrap_security_setting
      security_setting = Organization.find(self.referer[:organization]).security_setting
      dump_data(security_setting, security_setting.class.name)
    end

    def scrap_organization_features
      # Assuming only one organization is being scrapped
      organization_features = Organization.find(self.referer[:organization]).organization_features
      dump_data(organization_features, "OrganizationFeature")
    end

    def scrap_organization_resources
      resources = Organization.find(self.referer[:organization]).resources
      export_ck_assets_related_content(resources, [:content])
      dump_data(resources, "Resource")
    end

    def scrap_programs
      programs = Program.includes(:translations).where(:parent_id => self.referer[:organization]).where(:root => self.programs)
      raise Exception.new("Programs not found") unless programs
      dump_data(programs, "Program")
      self.referer[:programs] = programs.collect(&:id)
    end

    def scrap_program_asset
      program_assets = ProgramAsset.where(program_id: self.referer[:programs] + [self.referer[:organization]])
      dump_data(program_assets, "ProgramAsset")
      location = ATTACHMENT_FOLDER + "program_assets/"
      SolutionPack.create_if_not_exist_with_permission(location, 0777)
      program_assets.each do |program_asset|
        SolutionPack::AttachmentExportImportUtils.handle_attachment_export(location, program_asset, :logo)
        SolutionPack::AttachmentExportImportUtils.handle_attachment_export(location, program_asset, :banner)
        SolutionPack::AttachmentExportImportUtils.handle_attachment_export(location, program_asset, :mobile_logo)
      end
    end

    def scrap_notification_settings
      notification_settings = NotificationSetting.where(:program_id => self.referer[:programs])
      dump_data(notification_settings, "NotificationSetting")
    end

    def scrap_solution_pack_settings
      self.referer[:programs].each do |program|
        # Create dummy solution pack object and donot persist the object
        solution_pack = SolutionPack.new(:program => Program.find(program), :is_sales_demo => true)
        solution_pack.export(target_location: Rails.root + LOCATION + "solution_pack_#{program}.zip")
      end
    end

    def scrap_membership_requests
      membership_requests = MembershipRequest.where(:program_id => self.referer[:programs])
      custom_dump(:membership_requests, MembershipRequestPopulator.dump_data(membership_requests))
    end

    def scrap_members
      members = Member.where(:organization_id => self.referer[:organization])
      raise Exception.new("Members not found") unless members
      dump_data(members, "Member")
      self.referer[:members] = members.collect(&:id)
    end

    def scrap_users
      users = User.where(:program_id => self.referer[:programs])
      custom_dump(:users, UserPopulator.dump_data(users))
      self.referer[:users] = users.collect(&:id)
    end

    def scrap_profile_pictures
      profile_pictures = ProfilePicture.where(:member_id => self.referer[:members])
      dump_data(profile_pictures, "ProfilePicture")
      location = ATTACHMENT_FOLDER + "profile_pictures/"
      SolutionPack.create_if_not_exist_with_permission(location, 0777)
      profile_pictures.each do |profile_picture|
        SolutionPack::AttachmentExportImportUtils.handle_attachment_export(location, profile_picture, :image)
      end
    end

    def scrap_profile_answers
      # profile answers scrapped are only related to member
      profile_answers = ProfileAnswer.where(:ref_obj_id => self.referer[:members], :ref_obj_type => "Member")
      dump_data(profile_answers, "ProfileAnswer")
      location = ATTACHMENT_FOLDER + "profile_answers/"
      SolutionPack.create_if_not_exist_with_permission(location, 0777)
      profile_answers.each do |profile_answer|
        SolutionPack::AttachmentExportImportUtils.handle_attachment_export(location, profile_answer, :attachment)
      end
      self.referer[:profile_answers] = profile_answers.collect(&:id)
    end

    def scrap_answer_choices
      answer_choices = AnswerChoice.where(ref_obj_id: self.referer[:profile_answers], ref_obj_type: ProfileAnswer.name)
      answer_choices += AnswerChoice.where(ref_obj_id: self.referer[:survey_answers], ref_obj_type: CommonAnswer.name)
      dump_data(answer_choices, "AnswerChoice")
    end

    def scrap_experiences
      experiences = Experience.where(:profile_answer_id => self.referer[:profile_answers])
      dump_data(experiences, "Experience")
    end

    def scrap_educations
      educations = Education.where(:profile_answer_id => self.referer[:profile_answers])
      dump_data(educations, "Education")
    end

    def scrap_publications
      publications = Publication.where(:profile_answer_id => self.referer[:profile_answers])
      dump_data(publications, "Publication")
    end

    def scrap_managers
      managers = Manager.where(:profile_answer_id => self.referer[:profile_answers])
      dump_data(managers, "Manager")
    end

    def scrap_user_settings
      user_settings = UserSetting.where(:user_id => self.referer[:users])
      dump_data(user_settings, "UserSetting")
    end

    def scrap_groups
      groups = Group.where(:program_id => self.referer[:programs])
      dump_data(groups, "Group")
      location = ATTACHMENT_FOLDER + "groups/"
      SolutionPack.create_if_not_exist_with_permission(location, 0777)
      groups.each do |group|
        SolutionPack::AttachmentExportImportUtils.handle_attachment_export(location, group, :logo)
      end
      self.referer[:groups] = groups.collect(&:id)
    end

    def scrap_scraps
      scraps = Scrap.where(:ref_obj_id => self.referer[:groups], :ref_obj_type => Group.to_s)
      invalid_scraps = scraps.select{|scrap| !scrap.group.present? || !scrap.sender.present? || !scrap.group.has_member?(scrap.sender_user) } # scrap scraps only if sender is part of group
      valid_scrap_ids = scraps.pluck(:id) - invalid_scraps.collect(&:siblings).flatten.collect(&:id)
      scraps = Scrap.where(:id => valid_scrap_ids)
      dump_data(scraps, "Scrap")
      location = ATTACHMENT_FOLDER + "scraps/"
      SolutionPack.create_if_not_exist_with_permission(location, 0777)
      scraps.each do |scrap|
        SolutionPack::AttachmentExportImportUtils.handle_attachment_export(location, scrap, :attachment)
      end
      self.referer[:scraps] = scraps.collect(&:id)
    end

    def scrap_scrap_receivers
      scrap_receivers = Scraps::Receiver.where(:message_id => self.referer[:scraps])
      dump_data(scrap_receivers, "Scraps::Receiver")
    end

    def scrap_connection_memberships
      connection_memberships = Connection::Membership.where(:group_id => self.referer[:groups])
      dump_data(connection_memberships, "Connection::Membership")
      self.referer[:connection_memberships] = connection_memberships.collect(&:id)
    end

    def scrap_mentoring_model_milestones
      mentoring_model_milestones = MentoringModel::Milestone.includes(:translations).where(:group_id => self.referer[:groups])
      dump_data(mentoring_model_milestones, "MentoringModel::Milestone")
      export_ck_assets_related_content(mentoring_model_milestones, [:description])
      self.referer[:mentoring_model_milestones] = mentoring_model_milestones.collect(&:id)
    end

    def scrap_mentoring_model_goals
      mentoring_model_goals = MentoringModel::Goal.includes(:translations).where(:group_id => self.referer[:groups])
      dump_data(mentoring_model_goals, "MentoringModel::Goal")
      export_ck_assets_related_content(mentoring_model_goals, [:description])
      self.referer[:mentoring_model_goals] = mentoring_model_goals.collect(&:id)
    end

    def scrap_mentoring_model_tasks
      mentoring_model_tasks = MentoringModel::Task.includes(:translations).where(:group_id => self.referer[:groups])
      dump_data(mentoring_model_tasks, "MentoringModel::Task")
      export_ck_assets_related_content(mentoring_model_tasks, [:description])
      self.referer[:mentoring_model_tasks] = mentoring_model_tasks.collect(&:id)
    end

    def scrap_object_role_permissions
      object_role_permissions = ObjectRolePermission.where(:ref_obj_type => "Group", :ref_obj_id => self.referer[:groups])
      custom_dump(:object_role_permissions, ObjectRolePermissionPopulator.dump_data(object_role_permissions))
    end

    def scrap_meeting_requests
      meeting_requests = MeetingRequest.where(:group_id => self.referer[:groups])
      dump_data(meeting_requests, "MeetingRequest")
      self.referer[:meeting_requests] = meeting_requests.collect(&:id)
    end

    def scrap_meetings
      meetings = Meeting.where(:program_id => self.referer[:programs])
      dump_data(meetings, "Meeting")
      self.referer[:meetings] = meetings.collect(&:id)
    end

    def scrap_member_meetings
      member_meetings = MemberMeeting.where(:meeting_id => self.referer[:meetings])
      dump_data(member_meetings, "MemberMeeting")
      self.referer[:member_meetings] = member_meetings.collect(&:id)
    end

    def scrap_survey_answers
      survey_answers = SurveyAnswer.where(:group_id => self.referer[:groups])
      dump_data(survey_answers, "SurveyAnswer")
      location = ATTACHMENT_FOLDER + "survey_answers/"
      SolutionPack.create_if_not_exist_with_permission(location, 0777)
      survey_answers.each do |survey_answer|
       SolutionPack::AttachmentExportImportUtils.handle_attachment_export(location, survey_answer, :attachment)
      end
      self.referer[:survey_answers] = survey_answers.collect(&:id)
    end


    def scrap_member_meeting_responses
      member_meetings = MemberMeeting.where(:meeting_id => self.referer[:meetings])
      meeting_responses = member_meetings.map{|mm| mm.member_meeting_responses.first}.compact!
      dump_data(meeting_responses, "MemberMeetingResponse")
    end

    def scrap_mentoring_model_templates
      mentoring_model_ids = MentoringModel.where(:program_id => self.referer[:programs]).pluck(:id)
      mentoring_model_milestone_templates = MentoringModel::MilestoneTemplate.includes(:translations).where(:mentoring_model_id => mentoring_model_ids)
      mentoring_model_goal_templates = MentoringModel::GoalTemplate.includes(:translations).where(:mentoring_model_id => mentoring_model_ids)
      mentoring_model_task_templates = MentoringModel::TaskTemplate.includes(:translations).where(:mentoring_model_id => mentoring_model_ids)
      dump_data(mentoring_model_milestone_templates, "MentoringModel::MilestoneTemplate")
      dump_data(mentoring_model_goal_templates, "MentoringModel::GoalTemplate")
      dump_data(mentoring_model_task_templates, "MentoringModel::TaskTemplate")
    end

    def scrap_goal_activities
      goal_activities = MentoringModel::Activity.where(:ref_obj_id => self.referer[:mentoring_model_goals], :ref_obj_type => "MentoringModel::Goal")
      dump_data(goal_activities, "MentoringModel::Activity")
    end

    def scrap_organization_admin_views
      organization_admin_views = Organization.find(self.referer[:organization]).admin_views
      dump_data(organization_admin_views, "AdminView")
      admin_view_columns = organization_admin_views.collect(&:admin_view_columns).flatten
      dump_data(admin_view_columns, "AdminViewColumn")
    end

    def scrap_group_checkins
      group_checkins = GroupCheckin.where(:program_id => self.referer[:programs])
      dump_data(group_checkins, "GroupCheckin")
    end

    def scrap_user_state_changes
      user_state_changes = UserStateChange.where(:user_id => self.referer[:users])
      dump_data(user_state_changes, "UserStateChange")
    end

    def scrap_group_state_changes
      group_state_changes = GroupStateChange.where(:group_id => self.referer[:groups])
      dump_data(group_state_changes, "GroupStateChange")
    end

    def scrap_connection_membership_state_changes
      connection_membership_state_changes = ConnectionMembershipStateChange.where(:connection_membership_id => self.referer[:connection_memberships])
      dump_data(connection_membership_state_changes, "ConnectionMembershipStateChange")
    end

    def scrap_pages
      pages = Page.where(program_id: self.referer[:organization])
      dump_data(pages, "Page")
      export_ck_assets_related_content(pages, [:content])
    end

    def scrap_page_translations
      page_translations = Page::Translation.where(page_id: self.referer[:pages])
      dump_data(page_translations, "Page::Translation")
      export_ck_assets_related_content(page_translations, [:content])
    end

    def scrap_activity_logs
      activity_logs = ActivityLog.where(:program_id => self.referer[:programs])
      dump_data(activity_logs, "ActivityLog")
    end

    def scrap_admin_messages
      admin_messages = AdminMessage.where(:program_id => self.referer[:programs])
      dump_data(admin_messages, "AdminMessage")
      export_ck_assets_related_content(admin_messages, [:content])
      self.referer[:admin_messages] = admin_messages.collect(&:id)
    end

    def scrap_admin_message_receivers
      admin_message_receivers = AdminMessages::Receiver.where(:message_id => self.referer[:admin_messages])
      dump_data(admin_message_receivers, "AdminMessages::Receiver")
    end

    def scrap_campaign_message_analyticss
      campaign_ids = CampaignManagement::AbstractCampaign.where(program_id: self.referer[:programs]).pluck(:id)
      campaign_message_ids = CampaignManagement::AbstractCampaignMessage.where(campaign_id: campaign_ids).pluck(:id)
      campaign_message_analyticss = CampaignManagement::CampaignMessageAnalytics.where( campaign_message_id: campaign_message_ids)
      dump_data(campaign_message_analyticss, "CampaignManagement::CampaignMessageAnalytics")
      campaign_emails = CampaignManagement::CampaignEmail.where(campaign_message_id: campaign_message_ids)
      dump_data(campaign_emails, "CampaignManagement::CampaignEmail")
      export_ck_assets_related_content(campaign_emails, [:source])
    end

    def scrap_program_invitations
      program_invitations = ProgramInvitation.where(program_id: self.referer[:programs])
      export_ck_assets_related_content(program_invitations, [:message])
      dump_data(program_invitations, "ProgramInvitation")
    end

    def scrap_connection_activities
      connection_activities = Connection::Activity.where(group_id: self.referer[:groups])
      dump_data(connection_activities, "Connection::Activity")
      self.referer[:recent_activities] = connection_activities.collect(&:recent_activity_id)
    end

    def scrap_recent_activities
      recent_activities = RecentActivity.where(id: self.referer[:recent_activities])
      dump_data(recent_activities, "RecentActivity")
    end

    def scrap_ckeditor_assets
      ckeditor_assets = Ckeditor::Asset.where(program_id: self.referer[:organization])
      dump_data(ckeditor_assets, "Ckeditor::Asset")
    end

    def dump_data(objects, class_name)
      objects = Array(objects)
      file_name = class_name.split("::").join.underscore.pluralize
      column_names = class_name.constantize.attribute_names
      converted_objects = objects.inject([]) do |collection, obj|
        collection << column_names.inject({}){|tmp, cname| tmp[cname] = obj.attributes[cname];tmp}
        collection
      end
      File.open(LOCATION + "#{file_name}.yml", "w"){|f| f.write(converted_objects.to_yaml)}
    end

    def custom_dump(file_name, objects)
      File.open(LOCATION + "#{file_name}.yml", "w"){|f| f.write(objects.to_yaml)}
    end

    def write_metadata
      metadata_hash = {
        ckeditor: { assets_base_url: "#{self.organization_url}" }
      }

      File.open(METADATA_FILE_PATH, "wb") do |f|
        f.write(metadata_hash.to_json)
      end
    end

    def create_zip_file
      SolutionPack::ExportImportCommonUtils.zip_all_files_in_dir(LOCATION.to_s)
      FileUtils.rm_rf LOCATION
    end

    private

    def export_ck_assets_related_content(assetable_objects, assetable_columns)
      return if assetable_objects.blank?
      assetable_objects.each do |assetable_object|
        assetable_columns.each do |assetable_column|
          content = assetable_object.send(assetable_column)
          next if content.blank?

          SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export_without_solution_pack(self.organization_url, content, self.exported_ck_assets, self.all_ck_assets, CKEDITOR_FOLDER)
        end
      end
      self.referer[assetable_objects.first.class.table_name.to_sym] = assetable_objects.collect(&:id)
    end
  end
end