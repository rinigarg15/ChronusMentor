class RemoveAssitantWorkOnBehalfFromFeatures< ActiveRecord::Migration[4.2]
  #TODO: Comment it once the migration is successful
  def up 
    ActionMailer::Base.perform_deliveries = false
    ActiveRecord::Base.transaction do

      #Remove manage_assistants permission -  this will automatically destroy corresponding role_permissions
      puts "Removing manage_assistants permission and corresponding role_permissions"
      Permission.find_by(name: "manage_assistants").try(:destroy)
      puts "=========================================="

      #Check for existing assistants, remove corresponding members
      puts "Removing assistants and their membership if no other role"
      members = Member.where id: ActiveRecord::Base.connection.execute("SELECT member_id AS id FROM assistants").to_a.flatten
      if members.present?
        members.each do |asst_member|
          if asst_member.has_no_users?
            asst_member.destroy
          end
        end
      end
      puts "=========================================="

      #Drop Assitant and AssistantInvitations Table if they exist      
      puts "Dropping assistants table"
      drop_table(:assistants)
      puts "=========================================="
      puts "Dropping assistant_invitations table"
      drop_table(:assistant_invitations)
      puts "=========================================="

      #Find AssistantWorkOnBehalf feature - if it exists, delete it - else do nothing
      #Destroy corresponding organization features
      puts "Destroy assistant_work_on_behalf feature along with entries in OrganizationFeature"
      feature_awob = Feature.find_by(name: "assistant_work_on_behalf")
      unless feature_awob.nil?
        OrganizationFeature.destroy_all(:feature_id => feature_awob.id)
        feature_awob.destroy
      end      
      puts "=========================================="

    end 
    ActionMailer::Base.perform_deliveries = true   
  end

  def down
   ActiveRecord::Base.transaction do

      Permission.create!(:name => "manage_assistants")
      
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
      end

      Feature.create!(:name => "assistant_work_on_behalf")
    end 
  end
end
