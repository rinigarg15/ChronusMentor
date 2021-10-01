module SalesDemo
  class AdminViewColumnPopulator < BasePopulator
    REQUIRED_FIELDS = AdminViewColumn.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :admin_view_columns)
    end

    def copy_data
      self.reference.each do |ref_object|
        avc = AdminViewColumn.new.tap do |admin_view_column|
          assign_data(admin_view_column, ref_object)
          admin_view_column.admin_view_id = master_populator.referer_hash[:admin_view][ref_object.admin_view_id]
          admin_view_column.profile_question_id = master_populator.solution_pack_referer_hash["ProfileQuestion"][ref_object.profile_question_id]
        end
        AdminViewColumn.import([avc], validate: false, timestamps: false)
      end
    end
  end
end