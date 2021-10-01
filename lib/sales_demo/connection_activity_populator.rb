module SalesDemo
  class ConnectionActivityPopulator < BasePopulator
    REQUIRED_FIELDS = Connection::Activity.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :connection_activities)
    end

    def copy_data
      self.reference.each do |ref_object|
        ca = Connection::Activity.new.tap do |connection_activity|
          assign_data(connection_activity, ref_object)
          connection_activity.group_id = master_populator.referer_hash[:group][ref_object.group_id]
          connection_activity.recent_activity_id = master_populator.referer_hash[:recent_activity][ref_object.recent_activity_id]
        end
        Connection::Activity.import([ca], validate: false, timestamps: false)
      end
    end
  end
end

