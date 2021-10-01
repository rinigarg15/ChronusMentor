class ThreeSixtyReviewerGroupPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    organization_ids = [@organization.id]
    three_sixty_reviewer_groups_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, organization_ids)
    process_patch(organization_ids, three_sixty_reviewer_groups_hsh) 
  end

  def add_three_sixty_reviewer_groups(organization_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Reviewer Group" do
      temp_organization_ids = organization_ids * count
      ThreeSixty::ReviewerGroup.populate(organization_ids.size * count) do |reviewer_group|
        name = Populator.words(3..6)

        reviewer_group.organization_id = temp_organization_ids.shift
        reviewer_group.name = DataPopulator.append_locale_to_string(name, I18n.default_locale)
        reviewer_group.threshold = rand(0..5)

        self.dot
      end
      self.class.display_populated_count(organization_ids.size * count, "Three Sixty Reviewer Group")
    end
  end

  def remove_three_sixty_reviewer_groups(organization_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Three Sixty Reviewer Group................" do
      reviewer_group_ids = ThreeSixty::ReviewerGroup.where(:organization_id => organization_ids).select([:id, :organization_id]).group_by(&:organization_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::ReviewerGroup.where(:id => reviewer_group_ids).destroy_all
      self.class.display_deleted_count(organization_ids.size * count, "Three Sixty Reviewer Group")
    end
  end
end