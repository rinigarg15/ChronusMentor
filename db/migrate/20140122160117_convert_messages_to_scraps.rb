class ConvertMessagesToScraps< ActiveRecord::Migration[4.2]
  def up
    ActionMailer::Base.perform_deliveries = false
    ActiveRecord::Base.transaction do
      AbstractMessageObserver.without_callback(:after_create) do
        groups_hash = {}
        message_participants_hash = {}
        messages_hash = {}
        say_with_time "Set1" do
          groups_hash = get_groups_hash
          scope = Message.joins(:message_receivers).select("message_id, CONCAT(sender_id, ',', member_id) as participant_ids")
          ActiveRecord::Base.connection.select_all(scope).each do |msg|
            if msg["participant_ids"].present?
              message_participants_hash[msg["message_id"]] = msg["participant_ids"].split(",").map(&:to_i).sort.map(&:to_s)
            end
          end
        end
        
        scope = Organization.select([:id, :parent_id])
        ActiveRecord::Base.connection.select_all(scope).each do |organization|
          say_with_time "program_id: #{organization["id"]}" do
            root_message_ids = Message.where(:program_id => organization["id"]).select("DISTINCT root_id").collect(&:root_id)
            root_message_ids.each do |message_id|              
              member_ids = message_participants_hash[message_id]
              if member_ids.present?
                common_groups_ids = groups_hash[member_ids]
                if common_groups_ids.present?
                  message_tree = Message.where(:root_id => message_id)
                  common_groups = Group.where(id: common_groups_ids).where('created_at < ?', message_tree.last.created_at).select("id, created_at, status, program_id")                  
                  if common_groups.present?
                    active_group = common_groups.find{|grp| grp.status == Group::Status::ACTIVE || grp.status == Group::Status::INACTIVE}
                    first_group = active_group.present? ? active_group : common_groups.first
                    remaining_groups = common_groups - [first_group]
                    create_new_threads_for_remaining_groups(message_tree, remaining_groups) if remaining_groups.present?
                    message_tree.each do |msg|
                      msg_id = msg.id
                      msg.type = Scrap.name
                      msg.group_id = first_group.id
                      msg.save(:validate => false)
                      scrap = AbstractMessage.find(msg_id)
                      scrap.old_message_id = msg_id
                      scrap.program_id = first_group.program_id
                      scrap.save(:validate => false)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def down
  end

  private

  def get_groups_hash
    groups_members_hash = {}
    groups_scope = Group.joins(:memberships => :user).group(:group_id).select("group_id, GROUP_CONCAT(member_id ORDER BY member_id ASC) as member_ids")
    ActiveRecord::Base.connection.select_all(groups_scope).each{ |grp| groups_members_hash[grp["group_id"]] = grp["member_ids"].split(',')}

    members_groups_hash = {}
    groups_members_hash.each {|group_id, member_ids|
      members_groups_hash[member_ids] ||= [] 
      members_groups_hash[member_ids] << group_id
    }
    members_groups_hash
  end

  def create_new_threads_for_remaining_groups(message_tree, remaining_groups)
    old_new_hash = {}
    remaining_groups.each do |group|
      message_tree.each do |msg|
        message_dup = msg.dup
        message_dup.created_at = msg.created_at
        message_dup.type = Scrap.name
        message_dup.group_id = group.id
        message_dup.save(:validate => false)

        old_new_hash[msg.id] = message_dup.id
        scrap = AbstractMessage.find(message_dup.id)
        scrap.old_message_id = msg.id
        scrap.program_id = group.program_id
        scrap.root_id = old_new_hash[scrap.root_id]
        scrap.parent_id = old_new_hash[scrap.parent_id]
        scrap.save(:validate => false)
        msg.message_receivers.each do |message_receiver|
          message_receiver_dup = message_receiver.dup
          message_receiver_dup.message_id = scrap.id
          ### Suspended members ###
          message_receiver_dup.save(:validate => false)
        end
      end      
    end
  end
end
