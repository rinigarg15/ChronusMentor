class CampaignManagement::CampaignEmail < ActiveRecord::Base
  self.table_name = 'cm_campaign_emails'

  belongs_to :campaign_message, foreign_key: "campaign_message_id", class_name: "CampaignManagement::AbstractCampaignMessage"
  # abstract_object_id is the parent id - for eg: it can be only program invitation as of now!
  # We are not storing email address directly here as it is assumed that can be fetched from the parent objects information. For eg: in this case, program invitation
  # change it to polymorphic association when started to use by other models as well.
  belongs_to :program_invitation, foreign_key: "abstract_object_id"
  validates :campaign_message_id, :abstract_object_id, :subject, :source,  :presence => true

  has_many  :event_logs,
            :dependent => :destroy,
            :class_name => "CampaignManagement::EmailEventLog",
            :foreign_key => "message_id",
            :as => :message
            
end
