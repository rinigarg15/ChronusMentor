module ViewCount
  extend ActiveSupport::Concern
  
  def hit!(update_timestamp = true)
    if update_timestamp
      self.view_count += 1
      self.save!
    else
      self.update_column(:view_count, self.view_count + 1)
    end
  end
end