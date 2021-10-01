# Passing conditions to delete_all is removed in Rails 5
# Hence, we have overridden with where(conditions).delete_all

SimpleCaptcha::SimpleCaptchaData.class_eval do

  def self.remove_data(key)
    self.where("#{connection.quote_column_name(:key)} = ?", key).delete_all
    clear_old_data(1.hour.ago)
  end

  def self.clear_old_data(time = 1.hour.ago)
    return unless Time === time

    self.where("#{connection.quote_column_name(:updated_at)} < ?", time).delete_all
  end
end