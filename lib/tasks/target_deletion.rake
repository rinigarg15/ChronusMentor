#usage: 
#1. collection and deletion by default: rake organization:destroy domain=<ORG DOMAIN> subdomain=<ORG SUBDOMAIN>
#2. collection only: rake organization:destroy domain=<ORG DOMAIN> subdomain=<ORG SUBDOMAIN> COLLECT_ONLY=true
#3. with file paths: rake organization:destroy domain=<ORG DOMAIN> subdomain=<ORG SUBDOMAIN> DB_FILE_PATH=<file path> S3_ASSET_FILE_PATH=<s3 collection file path>
namespace :organization do
  desc "Used for deleting of an entire Organization"
  task :destroy => :environment do
    domain = ENV["domain"] || DEFAULT_DOMAIN_NAME
    subdomain = ENV["subdomain"]
    collect_only = ENV["COLLECT_ONLY"] || false
    organization = Program::Domain.get_organization(domain, subdomain)
    raise "Organization not present" unless organization.present?
    id = organization.id
    #to load all the class paths for getting proper associations
    Rails.application.eager_load!
    parameters = ["Organization", id, {:db_file_path => ENV['DB_FILE_PATH'], :s3_asset_file_path => ENV['S3_ASSET_FILE_PATH'], :operation => OrganizationData::TargetCollection::OPERATION::COLLECT_FOR_DELETE}]
    model_collection = OrganizationData::TargetCollection.new(*parameters)
    model_collection.collect_data
    model_deletion = OrganizationData::TargetDeletion.new(*parameters[1..-1])
    unless collect_only
      model_deletion.delete_db_data
      model_deletion.delete_s3_data
      #Other items to take care of 
      puts %{Please take care of the below items also - 
        1. Remove ssl certificate if available from s3.
        2. Remove sftp account if available in sftp server.
        3. Remove feeds folder from S3 if available.
        4. Remove SAML SSO files from S3 if available. }
    end
    print_errors(model_collection.get_errors + model_deletion.get_errors)
  end

  #Usage: rake organization:bulk_destroy ORG_IDS="1,2,3,4"
  #Give a max of 10 orgs to limit load
  desc "Used to destroy multiple organizations with IDs"
  task :bulk_destroy => :environment do
    org_count = 0
    org_ids = (ENV['ORG_IDS'].present? ? ENV['ORG_IDS'].split(',').collect(&:to_i) : [])
    organizations_to_delete = Organization.where(:id => org_ids)
    orgs_to_be_deleted = organizations_to_delete.collect(&:url)
    raise "Give a valid Organization ID" if organizations_to_delete.empty?
    organizations_to_delete.each do |organization|
      unless organization.active?
        Rails.application.eager_load!
        puts "Deleting #{organization.name}"
        parameters = ["Organization", organization.id, {:operation => OrganizationData::TargetCollection::OPERATION::COLLECT_FOR_DELETE}]
        model_collection = OrganizationData::TargetCollection.new(*parameters)
        model_collection.collect_data
        model_deletion = OrganizationData::TargetDeletion.new(*parameters[1..-1])
        model_deletion.delete_db_data
        model_deletion.delete_s3_data
        print_errors(model_collection.get_errors + model_deletion.get_errors)
        org_count +=1
      end
    end
    puts "Orgs to be deleted:"
    puts orgs_to_be_deleted
    puts "Count: #{orgs_to_be_deleted.count}"
    puts "Actual orgs deleted: #{org_count}"
  end

  def print_errors(errors)
    puts "No errors" if errors.blank?
    errors.each do |error|
      puts error
    end
  end
end