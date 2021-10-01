class SplitNameIntoFirstLastMembershipRequests< ActiveRecord::Migration[4.2]
  def up
    add_column :membership_requests, :first_name, :string
    add_column :membership_requests, :last_name, :string
    MembershipRequest.select("id, name, first_name, last_name").each do |mem_req|
      first_name = guessed_first_name(mem_req[:name]).gsub('"', '')      
      last_name = guessed_last_name(mem_req[:name]).gsub('"', '')      
      ActiveRecord::Base.connection.execute("UPDATE membership_requests SET first_name = \"#{first_name}\" where id = #{mem_req.id}")
      ActiveRecord::Base.connection.execute("UPDATE membership_requests SET last_name = \"#{last_name}\" where id = #{mem_req.id}")
    end    
    remove_column :membership_requests, :name
  end

  def down
  end

  def guessed_first_name(name)
    split = name.split(' ')
    split.size > 1 ? split[0..-2].join(' ') : ' '
  end

  def guessed_last_name(name)
    split = name.split(' ')
    split.size > 1 ? split.last : name
  end
end
