module SalesDemo
  class GroupPopulator < BasePopulator
    REQUIRED_FIELDS = Group.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :closed_at, :expiry_time, :last_activity_at, :logo_updated_at, :last_member_activity_at, :published_at, :pending_at]

    ASSOCIATED_MODELS = {
      :connection_memberships => "SalesDemo::ConnectionMembershipPopulator"
    }

    attr_accessor :associated_model_reference

    def initialize(master_populator)
      super(master_populator, :groups)
      self.associated_model_reference = group_associated_models
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        g = Group.new.tap do |group|
          assign_data(group, ref_object)
          group.terminator_id = master_populator.referer_hash[:user][ref_object.terminator_id]
          group.creator_id = master_populator.referer_hash[:user][ref_object.creator_id]
          group.program_id = master_populator.referer_hash[:program][ref_object.program_id]
          group.closure_reason_id = master_populator.solution_pack_referer_hash["GroupClosureReason"][ref_object.closure_reason_id.to_i]
          group.mentoring_model_id = master_populator.solution_pack_referer_hash["MentoringModel"][ref_object.mentoring_model_id.to_i]
        end
        Group.import([g], validate: false, timestamps: false)
        group = Group.last
        group.skip_observer = true
        copy_associated_models(group, ref_object.id)
        SolutionPack::AttachmentExportImportUtils.handle_attachment_import(SalesPopulator::ATTACHMENT_FOLDER + "groups/", group, :logo, group.logo_file_name, ref_object.id)
        copy_associated_referer_ids(group, ref_object)
        referer[ref_object.id] = group.id
      end
      master_populator.referer_hash[:group] = referer
    end

    def copy_associated_models(group, ref_object_id)
      ASSOCIATED_MODELS.each do |key, value|
        value.constantize.new(group, associated_model_reference[key][ref_object_id] || [], master_populator).copy_data
      end
    end

    def copy_associated_referer_ids(group, ref_object)
      new_id_map = group.memberships.inject({}) do |map, membership|
        map[membership.user_id] = membership.id
        map
      end
      if associated_model_reference[:connection_memberships][ref_object.id].present?
        old_id_map = associated_model_reference[:connection_memberships][ref_object.id].inject({}) do |old_id_map, value|
          old_id_map[master_populator.referer_hash[:user][value.user_id]] = value.id
          old_id_map
        end
      end

      master_populator.referer_hash[:connection_membership] ||= {}
      master_populator.referer_hash[:connection_membership].merge!(new_id_map.keys.inject({}) do |id_map, key|
        id_map[old_id_map[key]] = new_id_map[key]
        id_map
      end)
    end

    def group_associated_models
      return ASSOCIATED_MODELS.keys.inject({}) do |associated_model_reference, key|
        associated_model_reference[key] = convert_to_objects(master_populator.parse_file(key)).group_by(&:group_id)
        associated_model_reference
      end
    end
  end
end
