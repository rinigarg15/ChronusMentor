class InactiveMemberManager
  def self.suspend!(filepath)
    arr = invalid_unique_emailids(filepath)
    arr.each do |email_id|
      person_accounts = Member.where("email = ?", email_id)
      person_accounts.each do |each_account|
        org_id = each_account.organization_id
        admin = Organization.find(org_id).members.where(admin: true).first
        each_account.suspend!(admin, "Inactive and Invalid members", false)
      end
    end
  end
  
  private
  
  def self.invalid_unique_emailids(filepath)
    arr = Array.new
    raise "File not present" unless File.exist?(filepath)
    File.open(filepath, "r") do |f|
      f.each_line do |line|
        arr.push(line.strip)
      end
    end
    return arr.uniq
  end
end