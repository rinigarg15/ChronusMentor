module DemoCampaignPopulator
  MONTHS_TO_BE_POPULATED = 3
  MAX_MAILS_PER_CAMPAIGN = 20

  def self.cleanup_analytical_data(campaigns)
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where(:campaign_id => campaigns.collect(&:id))
    campaign_messages_ids = campaign_messages.collect(&:id)

    # Cleanup of old data
    AdminMessage.where(:campaign_message_id => campaign_messages_ids).update_all(:campaign_message_id => nil)
    CampaignManagement::CampaignMessageAnalytics.where(:campaign_message_id => campaign_messages_ids).delete_all
  end

  def self.setup_random_creation_times_for_campaigns(campaigns)
        # update the start time, so that it is clear in the graphs
    campaigns.each do |campaign|
      # TODO: Check this logic
      created_time = get_rand_time(MONTHS_TO_BE_POPULATED.month.ago.to_f, (MONTHS_TO_BE_POPULATED-1).month.ago.to_f)
      campaign.update_attributes(:created_at => created_time, :updated_at => created_time)
    end
  end

  def self.generate_admin_messages(program, campaigns)
        # Create admin messages over the last few months
    current_time = Time.now
    user_objs = program.users.includes(:member).limit(MAX_MAILS_PER_CAMPAIGN)
    user_ids = user_objs.pluck(:id)
    organization = program.organization
    first_admin_member = program.admin_users.first.member

    email_count = user_ids.count
    campaigns.each do |campaign|
      next if email_count.zero?

      # Going with only one campaign message now
      dcm = campaign.campaign_messages.first

      next if dcm.nil?

      # Random sent count generator
      analytics = {}
      remaining = email_count

      (0..MONTHS_TO_BE_POPULATED-1).each do |index|
        cnt = remaining.to_f * rand
        remaining -= cnt
        time = current_time - index.month
        year_month_key = CampaignManagement::AbstractCampaignMessage.get_analytics_summary_key(time)
        sent_count = [1, cnt.to_i].max
        delivered_count = [1, rand((9*sent_count.to_f/10)..sent_count)].max
        opened_count = [1, rand((6*delivered_count.to_f/10)..delivered_count.to_f)].max
        clicked_count = [1, rand((3*opened_count.to_f/10)..(6*opened_count.to_f/10))].max

        analytics[year_month_key] = {}
        analytics[year_month_key]['start_time'] = time
        analytics[year_month_key]['sent'] = sent_count
        analytics[year_month_key][ChronusMentorMailgun::Event::DELIVERED] = delivered_count
        analytics[year_month_key][ChronusMentorMailgun::Event::OPENED] = opened_count
        analytics[year_month_key][ChronusMentorMailgun::Event::CLICKED] = clicked_count
      end

      analytics.each do |year_month_key, monthly_analytics|
        start_time = monthly_analytics['start_time']
        sent_count = monthly_analytics['sent']
        sent_count.times do
          user_id = user_ids.sample
          user = User.find(user_id)
          template = dcm.email_template
          member = user.member

          mail = UserCampaignEmailNotification.replace_tags(user, template)
          time = start_time
          program.admin_messages.create!(
                sender: first_admin_member,
                subject: mail[:subject].to_s,
                content: mail[:message].to_s,
                receivers: [member],
                auto_email: true,
                campaign_message_id: dcm.id,
                created_at: time,
                updated_at: time,
                no_email_notifications: true
              )
        end

        # Populate other analytics
        CampaignManagement::CampaignMessageAnalytics.create!(
          :campaign_message_id => dcm.id,
          :year_month => year_month_key,
          :event_type => CampaignManagement::EmailEventLog::Type::DELIVERED,
          :count => monthly_analytics[ChronusMentorMailgun::Event::DELIVERED]
          ) 

        CampaignManagement::CampaignMessageAnalytics.create!(
          :campaign_message_id => dcm.id,
          :year_month => year_month_key,
          :event_type => CampaignManagement::EmailEventLog::Type::OPENED,
          :count => monthly_analytics[ChronusMentorMailgun::Event::OPENED]
          ) 

        CampaignManagement::CampaignMessageAnalytics.create!(
          :campaign_message_id => dcm.id,
          :year_month => year_month_key,
          :event_type => CampaignManagement::EmailEventLog::Type::CLICKED,
          :count => monthly_analytics[ChronusMentorMailgun::Event::CLICKED]
          ) 
      end
    end
  end

  def self.import_default_campaigns(program)
    file_to_import = "demo_default_campaigns.csv"
    csv_content = File.read(Rails.root.join('demo','campaign_management', file_to_import))
    importer = CampaignManagement::Importer.new(csv_content, program.id)
    importer.import
  end

  # It unlinks the existing campaign messages
  def self.setup_program_with_default_campaigns(program_id)
    program = Program.find(program_id)
    import_default_campaigns(program)
    CampaignPopulator.link_program_invitation_campaign_to_mailer_template(program_id)
    campaigns   = program.user_campaigns.reload
    cleanup_analytical_data(campaigns)
    setup_random_creation_times_for_campaigns(campaigns)
    generate_admin_messages(program, campaigns)
  end

  def self.get_rand_time(start_time, end_time)
    Time.at((end_time.to_f - start_time.to_f)*rand + start_time.to_f)
  end
end