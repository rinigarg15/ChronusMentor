namespace :cm do
  desc "Customized mailer templates migration to Program Invitation Campaign"
  task :migrate_templates => :environment do
    file_name = ENV['CUSTOMIZED_TEMPLATE_FILE'].to_s
    migration_needed_for_old_updated_email_template_content(file_name)
  end

  desc "Removing mailer templates associated with Admin Invitation"
  task :remove_templates => :environment do
    remove_email_templates_from_email_listing
  end

  desc "Adding default content and campaign_id for mailer templates copied from organization level"
  task :add_template_to_campaign_messages => :environment do
    add_mailer_template_to_campaign_messages
  end

  desc "Run cleanup items for all disabled user campaigns"
  task :run_cleanup_items_for_disabled_campaigns => :environment do
    CampaignManagement::UserCampaign.stopped.each {|uc| uc.cleanup_items_when_not_active}
  end

  desc "Setting not started state for active user campaigns without campaign messages"
  task :set_draft_state_for_empty_campaigns => :environment do
    set_draft_state_for_empty_campaigns
  end
end

private

  def set_draft_state_for_empty_campaigns
    non_empty_campaign_ids = CampaignManagement::UserCampaignMessage.pluck(:campaign_id).uniq
    CampaignManagement::UserCampaign.active.where("id NOT IN (?)", non_empty_campaign_ids).update_all(state: CampaignManagement::AbstractCampaign::STATE::DRAFTED, enabled_at: nil)
    CampaignManagement::UserCampaign.drafted.each {|uc| uc.cleanup_items_when_not_active}
  end

  def migration_needed_for_old_updated_email_template_content(file_name)
    old_updated_email_template_content_with_all_valid_tags = read_csv_and_get_names_of_programs_where_old_updated_content_with_all_valid_tags_is_to_be_uploaded(file_name)
    #[{"id": 78, "uid": InviteNotificationFromAdmin"}]

    conflicting_program_ids = script_for_finding_programs_where_both_expiry_templates_are_customized(old_updated_email_template_content_with_all_valid_tags)

    programs_having_duplicate_mailer_template_uids = script_for_catching_duplicate_entries
    unsupported_tags = script_for_catching_unsupported_tags(["invitor_name","role_name","as_role_name_articleized","url_invitation","invitation_expiry_date","subprogram_or_program_name","url_subprogram_or_program","url_contact_admin"])

    puts "Programs_where_both_expiry_templates_are_customized are: " + conflicting_program_ids.to_s
    puts "Programs_having_duplicate_mailer_template_uids are: " + programs_having_duplicate_mailer_template_uids.to_s
    puts "All unsupported tags are: " + unsupported_tags.to_s
    puts "Unique unsupported tags are: " + unsupported_tags.uniq.to_s
    old_updated_email_template_content_with_all_valid_tags.each do |program_or_organization_content|
      program = Mailer::Template.find(program_or_organization_content["id"]).program
      if program.is_a?(Organization)
        # first taking care of the changes at organization level.
        program.programs.each do |prog|
          update_emails(prog, program_or_organization_content)
        end
      end
    end

    old_updated_email_template_content_with_all_valid_tags.each do |program_or_organization_content|
      program = Mailer::Template.find(program_or_organization_content["id"]).program
      if !program.is_a?(Organization)
        # overriding the changes at organization level with the program level if there is any such case
        update_emails(program, program_or_organization_content)
      end
    end
  end

  def remove_email_templates_from_email_listing
    template_uids = ['xka3347e', 'yhleyctl', 'opzw9h5d']
    #uids for the templates [InviteNotificationFromAdmin, InviteExpiryNotification, InviteExpiryNotificationWithoutRoles]
    Mailer::Template.where(:uid => template_uids).destroy_all
  end

  def read_csv_and_get_names_of_programs_where_old_updated_content_with_all_valid_tags_is_to_be_uploaded(file_name)
    csv_text = File.read(Rails.root.join('vendor/engines/campaign_management/files/', file_name))
    csv = CSV.parse(csv_text, :headers => true)
    csv.map {|row| row.to_hash }
  end

  def update_emails(program, program_or_organization_content)
    source = program_or_organization_content["source"].gsub(/{{widget_signature}}/, '')
    subject = program_or_organization_content["subject"].gsub(/{{widget_signature}}/, '')
    if program_or_organization_content["uid"].to_s == "InviteExpiryNotification" || program_or_organization_content["uid"].to_s == "InviteExpiryNotificationWithoutRoles"
      if program.program_invitation_campaign.campaign_messages.count == 3
        #what if they customized the expiry template and then disabled one of the expiry templates
        expiry_email = program.reload.program_invitation_campaign.campaign_messages.last.email_template
        expiry_email.source = source
        expiry_email.subject = subject
        expiry_email.save!
      end
    end
    if program_or_organization_content["uid"].to_s  == "InviteNotificationFromAdmin" || program_or_organization_content["uid"].to_s  == "InviteNotificationWithoutRoles"
      expiry_email = program.reload.program_invitation_campaign.campaign_messages.first.email_template
      expiry_email.source = source
      expiry_email.subject = subject
      expiry_email.save!
    end
  end

  def script_for_finding_programs_where_both_expiry_templates_are_customized(old_updated_email_template_content_with_all_valid_tags)
    new_updated_email_template_content_with_all_valid_tags = []
    old_updated_email_template_content_with_all_valid_tags.each do |program_or_organization_content|
      program_id = Mailer::Template.find(program_or_organization_content["id"]).program.id
      program_or_organization_content = program_or_organization_content.merge({"program_id"=> program_id})
      new_updated_email_template_content_with_all_valid_tags << program_or_organization_content
    end
    grouped_hash = new_updated_email_template_content_with_all_valid_tags.group_by {|h| h["program_id"]}
    group = grouped_hash.map {|array| {array.first => array.last.map{|ele| ele["uid"]}}}
    conflicting_program_ids = group.map {|g| g.keys.first if g.values.first.include?("InviteExpiryNotification") && g.values.first.include?("InviteExpiryNotificationWithoutRoles")}

    conflicting_program_ids.compact
    #might include organization ids as well
  end

  def script_for_catching_duplicate_entries
    dup = []
    Program.active.each do |program|
      #uids for the templates [InviteExpiryNotification, InviteExpiryNotificationWithoutRoles]
      program_or_organization_id = program.standalone? ? program.organization.id : program.id
      templates = Mailer::Template.where(:program_id => program_or_organization_id, :uid => 'yhleyctl')
      if templates.size > 1
        dup << {program_or_organization_id => 'yhleyctl'}
      end
      templates = Mailer::Template.where(:program_id => program_or_organization_id, :uid =>  'opzw9h5d')
      if templates.size > 1
        dup << {program_or_organization_id => 'opzw9h5d'}
      end
    end
    dup
  end

  def script_for_catching_unsupported_tags(list_of_supported_tags)
    uids = ['xka3347e', 'yhleyctl', 'opzw9h5d']
    unsupported_tags = []
    Program.active.each do |program|
      templates = Mailer::Template.where(:program_id => program.id, :uid => uids)
      unsupported_tags.concat(get_unsupported_tags(templates, list_of_supported_tags))
    end

    Organization.active.each do |org|
      templates = Mailer::Template.where(:program_id => org.id, :uid => uids)
      unsupported_tags.concat(get_unsupported_tags(templates, list_of_supported_tags))
    end
    unsupported_tags
  end

  def get_unsupported_tags(templates, list_of_supported_tags)
    unsupported_tags = []
    templates.each do |template|
      tags = []
      if !template.source.nil?
        source_tags = template.source.scan( /{{([^}}]*)}}/)
        tags = source_tags.map {|tag| tag.first}
      end
      if !template.subject.nil?
        subject_tags = template.subject.scan( /{{([^}}]*)}}/)
        tags.concat(subject_tags.map {|tag| tag.first})
      end
      tags.each do |tag|
        if !list_of_supported_tags.include?(tag)
          unsupported_tags << tag
        end
      end
    end
    unsupported_tags
  end

  def add_mailer_template_to_campaign_messages
    Program.includes(:program_invitation_campaign => [:campaign_messages => :email_template]).active.each do |program|
      campaign_message = program.program_invitation_campaign.campaign_messages.first
      if campaign_message.email_template.nil?
        template = program.mailer_templates.where(:uid => ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]).first
        unless template.nil?
          template.subject = "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}"
          template.source = "Hello,<br /><br />I would like to invite you to join the&nbsp;{{subprogram_or_program_name}} {{as_role_name_articleized}}.<br /><br /><a href=""{{url_invitation}}"">Click here</a> to accept the invitation and sign up for {{subprogram_or_program_name}}. Once you do that, you can fill out your profile (which we use to match you up with other participants with similar interests and goals) and participate in the program activities.<br /><br />I look forward to your participation! If you have any questions, please contact me <a href=""{{url_contact_admin}}"">here</a>."
          template.campaign_message_id = campaign_message.id
          template.save!
          puts "Organization: #{program.organization.subdomain}.#{program.organization.domain}, Campaign message id: #{campaign_message.id} for program: #{program.name} program_id: #{program.id}.\n"
        end
      end
    end
  end