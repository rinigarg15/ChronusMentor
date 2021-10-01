class ScrapPopulator < PopulatorTask
   ALLOWED_GROUP_STATE = [Group::Status::CLOSED, Group::Status::ACTIVE, Group::Status::INACTIVE]
  def patch(options = {})
    return unless @program.engagement_enabled?
    group_ids = @program.groups.where(status: ALLOWED_GROUP_STATE).pluck(:id)
    scraps_hsh = Scrap.where(ref_obj_id: group_ids, ref_obj_type: Group.name).pluck(:ref_obj_id).group_by{|x|x}
    process_patch(group_ids, scraps_hsh)
  end

  def add_scraps(group_ids, count, options)
    self.class.benchmark_wrapper "Scraps, Scraps:Receivers" do
      temp_groups = Group.where(:id => group_ids).includes(:members).to_a * count
      Scrap.populate(group_ids.size * count, :per_query => 50_000) do |scrap|
        group = temp_groups.shift
        membership_ids = group.members.pluck(:member_id)
        scrap.ref_obj_id = group.id
        scrap.ref_obj_type = Group.to_s
        scrap.program_id = group.program_id
        scrap.sender_id = membership_ids.first
        membership_ids = membership_ids.rotate
        scrap.subject = Populator.words(8..12)
        scrap.content = Populator.paragraphs(1..3)
        scrap.created_at = group.created_at..Time.now
        scrap.type = Scrap.name
        scrap.auto_email = false
        scrap.root_id = scrap.id
        receiver_ids = membership_ids - [scrap.sender_id]
        Scraps::Receiver.populate (membership_ids - [scrap.sender_id]).size do |scrap_receiver|
          scrap_receiver.member_id = receiver_ids.shift
          scrap_receiver.message_id = scrap.id
          scrap_receiver.status = [AbstractMessageReceiver::Status::UNREAD, AbstractMessageReceiver::Status::READ].sample
          scrap_receiver.api_token = "scraps-api-token-#{rand(36**36).to_s(36)}"
          scrap_receiver.message_root_id = scrap.id
        end
        self.dot
      end
      self.class.display_populated_count(group_ids.size * count, "Scraps")
    end
  end

  def remove_scraps(group_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Scraps................" do
      program = options[:program]
      scrap_ids = program.scraps.where(:ref_obj_id => group_ids, :ref_obj_type => Group.to_s).select([:id, :ref_obj_id]).group_by(&:ref_obj_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.scraps.where(:id => scrap_ids).destroy_all
      self.class.display_deleted_count(group_ids.size * count, "Scraps")
    end
  end
end