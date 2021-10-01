class CampaignPopulator

  def self.import_default_campaigns(program, csv_files)
    csv_files.each do |csv_file|
      file_to_import = csv_file
      csv_content = File.read(Rails.root.join('vendor/engines/campaign_management/files/', file_to_import))
      importer = CampaignManagement::Importer.new(csv_content, program.id)
      importer.import
    end
  end

  def self.setup_program_with_default_campaigns(program_id, csv_files)
    program = Program.find(program_id)
    CampaignPopulator.import_default_campaigns(program, csv_files)
  end

  def self.link_program_invitation_campaign_to_mailer_template(program_id)
    program = Program.find(program_id)
    first_email_template = program.reload.program_invitation_campaign.campaign_messages.first.email_template
    first_email_template.uid = ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid]
    first_email_template.save!
  end

end