module CampaignManagement::ImportExportUtils

  module CampaignTemplate
    BLOCK_IDENTIFIER = '#Campaign'
    HEADER = ["Name", "AdminView", "Enable", "Type"]
    FIELD_HEADER_ORDER = [:title, :trigger_params, :state, :type]
    DATA_INTERPRETOR = {
      trigger_params: (->(x,options){
        admins_views = {}
        begin
          admins_views[1] = [Program.find(options[:program_id]).admin_views.where(:title => x).first.id]
        rescue
          return nil
        end
        return admins_views
        }),
      state: (->(x,options){ 
        if x.present?
          case x.strip.downcase
          when "yes"
            return CampaignManagement::AbstractCampaign::STATE::ACTIVE
          when "no"
            return CampaignManagement::AbstractCampaign::STATE::STOPPED
          when "draft"
            return CampaignManagement::AbstractCampaign::STATE::DRAFTED
          end
        else
          #if enabled field is left blank, we take the state as INACTIVE.
          return CampaignManagement::AbstractCampaign::STATE::STOPPED
        end
      }),
      type: (->(x,options){ 
        if x.present? 
          x.strip.downcase.eql?("ProgramInvitation".downcase) ? "CampaignManagement::ProgramInvitationCampaign" : "CampaignManagement::UserCampaign"  
        else
          "CampaignManagement::UserCampaign"
        end
      })
    }
  end

  module CampaignMessageTemplate
    BLOCK_IDENTIFIER = '#Emails'
    HEADER = ["Subject", "Message", "Schedule", "Campaign"]
    FIELD_HEADER_ORDER = [:subject, :source, :duration, :campaign_id]
    DATA_INTERPRETOR = {
      duration: (->(x,options){ x.present? ? x.strip.to_i : 0 }),
      campaign_id:  (->(x,options){
        if x.present?
          campaign = options[:campaign_referenced_by_title][x.strip]
          if campaign != nil
            x && campaign.try(:id)
          else
            return false
          end
        else
          return false
        end
      })
    }
  end

end