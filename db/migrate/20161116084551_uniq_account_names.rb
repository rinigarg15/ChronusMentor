class UniqAccountNames< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      Organization.all.group_by(&:account_name).each do |account_name, organizations|
        next if organizations.size <= 1
        organizations.each do |organization|
          organization.update_attribute(:account_name, (organization.account_name.presence || "<blank>") + " - " + organization.id.to_s)
        end
      end
    end
  end

  def down
  end
end
