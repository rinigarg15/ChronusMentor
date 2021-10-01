require 'rubygems'
require 'csv'

admin_email_ids = []

def is_weekly_mail?(row)
  from, to, subject = row[2..4]
  if subject =~ /Weekly program activity/
    return true
  end
end
def identify_program_from_admin_email(email, admin_email_ids)
  admin_email_ids << email
  admin_email_ids.uniq!
end

def is_membership_request_mail?(row)
  from, to, subject = row[2..4]
  if subject =~ /pending membership request/ 
    # identify_program_from_admin_email(to, admin_email_ids)
    return true
  end
end

def is_program_mail?(row,programs)
  from, to, subject = row[2..4]
  programs.each do |key,value|
    if ((from =~ (/#{key}/i)) ||(to =~ (/#{key}/i)) || (subject =~ (/#{key}/i)))
      programs[key] += 1
      return true
    end
  end
  return false
end

def is_system_mail?(row)
      from, to, subject = row[2..4]
      return (from =~ (/#{"Cron"}/i)) || (subject =~ (/#{"(Linux)"}/i))
end

def is_profile_update?(row)
      from, to, subject = row[2..4]
      return (subject =~ (/#{"(Profile question updated)"}/i))
end


def junk_mail?(row)
  return true
end

array_of_arrays = CSV.read("authsmtp-bkp.csv")
array_of_arrays.slice!(0)
programs = {"SRM"=> 0 ,"IISC" => 0,"DCSE" => 0,"NWEN" => 0,"IITB"=> 0,"PSG"=> 0,"IIT Kanpur" => 0,"SJMSOM" => 0,"Walkthru" => 0,"Walkthrough" => 0,"JBIMS"=> 0,"MBA"=> 0,"IV INVENTOR"=> 0 }

admins = {
  "SRM"=> ['srmadmin@chronus.com', 'anuradha@srmuniv.ac.in', 'ravindrandi@yahoo.com'],
  "IISC" => [],
  "DCSE" => ['dcseaucadmin@chronus.com', 'easwara@cs.annauniv.edu'],
  "NWEN" => ["nathan@npost.com", 'nkaiser@gmail.com'],
  "IITB"=> [],
  "PSG"=> ['madhan@chronuscorp.com'],
  "IIT Kanpur" => ['babita@iitk.ac.in'],
  "SJMSOM" => [],
  "Walkthru" => [],
  "Walkthrough" => ['walkthru_srini@chronus.com', 'mrudhubatchu@yahoo.com', 'vvikra_m@yahoo.com'],
  "JBIMS"=> [],
  "MBA"=> [],
  "IV INVENTOR"=> []
}

from = String.new
subject = String.new
to = String.new
junk = 0
system = 0
profile = 0
weekly_mail = 0
membership_requests = 0
array_of_arrays.each do |row|
  
    if is_membership_request_mail?(row)
      membership_requests += 1   
    elsif is_program_mail?(row, programs)
       #do nothing
    elsif is_system_mail?(row)
      system += 1
    elsif is_profile_update?(row)
      profile += 1
    elsif is_weekly_mail?(row)
      weekly_mail += 1
    elsif junk_mail?(row)
      puts row.inspect
      junk += 1
    end
  
end

  puts programs.inspect
  prog_mails = programs.values.inject(0) {|i, j| i += j }
  puts "Total program mails:              #{prog_mails}"
  puts "System mail (Cron mails):         " + system.to_s
  puts "Profile question updated:         " + profile.to_s
  puts "Membership request notifications: #{membership_requests}"
  puts "Weekly mails:                     #{weekly_mail} "
  puts "Remaining junk:                   " + junk.to_s
  puts "Total mails identified:           #{prog_mails + system + profile + membership_requests + junk + weekly_mail}"
  puts "Total mails enties in log:        #{array_of_arrays.size}"


  puts admin_email_ids.join(", ")
