class PopulateFeaturedCampaignForAllPrograms < ActiveRecord::Migration[4.2]

  def up
    Program.active.each do |program|
      if program.program_invitation_campaign
        program.program_invitation_campaign.destroy
      end
      csv_files = ["featured_campaigns.csv"]
      CampaignPopulator.setup_program_with_default_campaigns(program.id, csv_files)
      program.reload
      CampaignPopulator.link_program_invitation_campaign_to_mailer_template(program.id)
      
      if !isTemplateEnabledForProg(program, 'yhleyctl') && !isTemplateEnabledForProg(program, 'opzw9h5d')
        program.reload.program_invitation_campaign.campaign_messages.last.destroy
        program.reload.program_invitation_campaign.campaign_messages.last.destroy
      end
      
    end  
  end

  def down
  end

  def isTemplateEnabledForProg(program, uid)
    template = Mailer::Template.where(:program_id => program.id, :uid => uid).first
    return template.enabled if template

    #see if template is disabled at the org level
    template = Mailer::Template.where(:program_id => program.organization.id, :uid => uid).first
    return template.enabled if template

    return true

  end
end