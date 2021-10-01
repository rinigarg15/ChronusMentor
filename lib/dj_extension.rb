class DJExtension
  def self.get_running_djs(class_name, method_name)
    return [] if class_name.blank? || method_name.blank?
    Delayed::Job.where("failed_at is null and handler like ?", "%object: !ruby/object:#{class_name.to_s}%method_name: :#{method_name.to_s}%")
  end
end
