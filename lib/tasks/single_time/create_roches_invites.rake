namespace :single_time do
  desc "Triggering invites from backend"
  task :triggering_invites => :environment do
    subdomain = ENV['SUBDOMAIN']
    domain = ENV['DOMAIN'] || DEFAULT_DOMAIN_NAME
    root = ENV['ROOT']
    organization = Program::Domain.get_organization(domain, subdomain)
    raise "Organization with domain: #{domain} and subdomain: #{subdomain} doesn't exist" unless organization.present?
    puts "Organization: #{organization.name}"
    @program = organization.programs.find_by(root: root)
    raise "Program with root: #{root} doesn't exist" unless @program.present?
    puts "Program: #{@program.name}"
    file_name = ENV['EMAIL_LIST_FILE'].to_s
    roles = ENV['ROLE'].to_s.split(" ")
    role_type = ENV['ROLE_TYPE']
    sender_email = ENV['SENDER_EMAIL']
    @sender_member = organization.members.find_by(email: sender_email)
    @sender = @program.users.find_by(member_id: @sender_member.id)
    @sanitization_version = organization.security_setting.sanitization_version
    trigger_invitations_from_backend(file_name, roles, role_type)
  end

  # Ex: bundle exec rake single_time:split_csvs MAX_ROWS=2000 CSV="/tmp/csvtest/emails_list.csv"
  task :split_csvs do
    max_rows = (ENV['MAX_ROWS'] || 2000).to_i
    csv_file_path = ENV['CSV']
    csv_records = CSV.read(csv_file_path)
    csvs_ary = csv_records.in_groups_of(max_rows)
    puts "Creating #{csvs_ary.size} csv files"
    csvs_ary.each_with_index do |records, index|
      target_path = csv_file_path.dup
      target_path.insert(target_path.index(".") || target_path.size, "_#{index + 1}")
      CSV.open(target_path, "w") do |csv|
        records.compact.each { |record| csv << record }
      end
      print "."
    end
    puts "\nDone"
  end

  desc "Deleting Unused Invites in a specified Date Range"
  task :deleting_unused_invites => :environment do
    subdomain = ENV['SUBDOMAIN']
    domain = ENV['DOMAIN'] || DEFAULT_DOMAIN_NAME
    root = ENV['ROOT']
    organization = Program::Domain.get_organization(domain, subdomain)
    raise "Organization with domain: #{domain} and subdomain: #{subdomain} doesn't exist" unless organization.present?
    puts "Organization: #{organization.name}"
    program = organization.programs.find_by(root: root)
    raise "Program with root: #{root} doesn't exist" unless program.present?
    puts "Program: #{program.name}"
    start_time = ENV['START_TIME'].to_datetime
    end_time = ENV['END_TIME'].to_datetime
    raise "Start Time Greater than End Time" if end_time < start_time
    puts "Total No of invites to be destroyed #{program.program_invitations.in_date_range(start_time, end_time).pending.size}"
    batch_size = ENV['BATCH_SIZE'].present? && ENV['BATCH_SIZE'].to_i || 100
    ActiveRecord::Base.transaction do
      index = 0
      program.program_invitations.in_date_range(start_time, end_time).pending.find_each(batch_size: batch_size) do |program_invitation|
        puts "Processing Program Invitation #{index+=1}"
        program_invitation.destroy
      end
    end
    puts ":::::::::::: Program Invitations - Destroyed ::::::::: "
  end

  private
  def trigger_invitations_from_backend(file_name, roles, role_type)
    all_recipients = CSV.read(file_name)
    all_recipients = all_recipients.collect {|row| row[0].strip.downcase}.uniq
    roles.sort!

    emails_in_the_program_with_roles = @program.users.active_or_pending.includes(:member, :roles).select {|user| (roles - user.role_names).empty?}.collect {|user| user.email.strip.downcase}
    pending_invites_for_roles = @program.program_invitations.pending.where(role_type: role_type).includes(:roles).select {|invite| (invite.role_names.sort == roles)}

    email_invite_map = pending_invites_for_roles.index_by { |invite| invite.sent_to.strip.downcase }
    emails_with_pending_invites_for_roles = email_invite_map.keys
    emails_not_part_of_the_program = all_recipients - emails_in_the_program_with_roles
    invitations_to_be_resent = emails_not_part_of_the_program & emails_with_pending_invites_for_roles
    new_invitations = emails_not_part_of_the_program - emails_with_pending_invites_for_roles

    puts "Total invitations to be sent: #{emails_not_part_of_the_program.size}"
    errors = []
    new_invitations.in_groups_of(250, false) do |recipients_batch|
      errors += make_invitations_for_roles(recipients_batch, roles, role_type)
    end

    invitations_to_be_resent.in_groups_of(250, false) do |recipients_batch|
      resend_invitations_for_roles(recipients_batch, email_invite_map)
    end

    puts "#{errors}"
    puts "Total Errors: #{errors.size}"
  end

  def make_invitations_for_roles(recipients, roles, role_type)
    errors = []
    invite_ids = []
    recipients.each do |recipient|
      begin
        invite = @program.program_invitations.build({:sent_to => recipient, :user => @sender, :role_type => role_type})
        assign_sanitization_version_and_user(invite)
        invite.role_names = roles
        invite.skip_observer = true
        invite.save!
        invite_ids << invite.id
        puts "invite to be processed: " + recipient
      rescue => error
        invite_ids -= [invite.id]
        errors << [recipient, error]
        puts "Error: #{recipient}, #{error}"
      end
    end
    ProgramInvitation.send_invitations(invite_ids, @program.id, @sender.id, skip_sending_instantly: true, is_sender_admin: true)
    puts "#{invite_ids.count} new invites sent successfully"
    errors
  end

  def resend_invitations_for_roles(recipients, email_invite_map)
    invite_ids = []
    recipients.each do |recipient|
      invite = email_invite_map[recipient]
      assign_sanitization_version_and_user(invite)
      invite_ids << invite.id
      puts "invite to be resent: " + recipient
    end
    ProgramInvitation.send_invitations(invite_ids, @program.id, @sender.id, update_expires_on: true, skip_sending_instantly: true, is_sender_admin: true, action_type: "Resend Invitations")
    puts "#{invite_ids.count} Invites re-sent successfully"
  end

  def assign_sanitization_version_and_user(invite)
    invite.current_user = @sender
    invite.current_member = @sender_member
    invite.sanitization_version = @sanitization_version
  end
end

