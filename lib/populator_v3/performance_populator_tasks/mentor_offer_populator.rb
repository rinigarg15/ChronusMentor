class MentorOfferPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    return if @program.project_based?
    mentor_ids = @program.users.active.includes(:groups, :roles).select{|user| user.is_mentor? && !user.groups.count.zero?}.collect(&:id)
    mentor_offers_hsh = get_children_hash(@program, @options[:args]["model"]||@node, @foreign_key, mentor_ids)
    process_patch(mentor_ids, mentor_offers_hsh) 
  end

  def add_mentor_offers(mentor_ids, count, options = {})
    self.class.benchmark_wrapper "Mentor Offer" do
      program = options[:program]
      mentors = program.users.active.where(:id => mentor_ids).select(:id)
      mentors.each do |mentor|
        temp_groups = mentor.groups.dup.to_a
        next if temp_groups.blank?
        MentorOffer.populate count do|mentor_offer|
          temp_groups = mentor.groups.dup.to_a if temp_groups.blank?
          group = temp_groups.shift
          mentor_offer.program_id = program.id
          mentor_offer.group_id = group.id
          mentor_offer.mentor_id = mentor.id
          mentor_offer.student_id = group.students.sample.id
          mentor_offer.message = Populator.sentences(2..3)
          mentor_offer.status = MentorOffer::Status::PENDING
          self.dot
        end
      end
      self.class.display_populated_count(mentor_ids.size * count, "Mentor Offers")
    end
  end

  def remove_mentor_offers(mentor_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Mentor Offers................" do
      program = options[:program]
      mentor_offer_ids = program.mentor_offers.where(:mentor_id => mentor_ids).select([:id, :mentor_id]).group_by(&:mentor_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.mentor_offers.where(:id => mentor_offer_ids).destroy_all
      self.class.display_deleted_count(mentor_ids.size * count, "Mentor Offers")
    end
  end
end