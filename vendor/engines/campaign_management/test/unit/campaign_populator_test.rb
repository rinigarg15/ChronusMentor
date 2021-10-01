require_relative './../test_helper'

class CampaignPopulatorTest < ActiveSupport::TestCase

  def test_setup_program_with_default_campaigns
    program = programs(:albers)
    CampaignPopulator.expects(:import_default_campaigns).once
    CampaignPopulator.setup_program_with_default_campaigns(program.id, [])
  end

  def test_should_import_default_campaigns
    program = programs(:albers)
    program.program_invitation_campaign.destroy
    csv_files = ["default_campaigns.csv", "featured_campaigns.csv"]
    assert_difference 'CampaignManagement::AbstractCampaign.count', 3 do
      CampaignPopulator.import_default_campaigns(program, csv_files)
    end

    assert program.program_invitation_campaign.featured
  end

  def test_link_program_invitation_campaign_to_mailer_template_should_link_uid_as_expected
    program = programs(:albers)

    template = program.program_invitation_campaign.campaign_messages.first.email_template
    template.uid = nil
    template.save!

    CampaignPopulator.link_program_invitation_campaign_to_mailer_template(program.id)
    template.reload
    assert_equal "z7hcgs54", template.uid    
  end
end

