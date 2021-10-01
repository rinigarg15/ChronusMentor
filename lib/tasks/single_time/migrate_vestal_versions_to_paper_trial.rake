#usage cap production deploy:invoke task="single_time:migrate_vestal_versions_to_paper_trial"
namespace :single_time do
  desc 'Migrate vestal versions data to chronus versions'
  task :migrate_vestal_versions_to_paper_trial => :environment do
    ActionMailer::Base.perform_deliveries = false
    start_time = Time.now
    batch_size = 50000
    chronus_versions = []
    columns = [:item_id, :item_type, :event, :object_changes, :created_at, :updated_at, :whodunnit]
    # making use of whodunnit column to migrate source audit key as we can't import source audit key through active record import
    ChronusVersion.record_timestamps = false
    if ENV['DELTA'].to_s.to_boolean
      delta_ids = VestalVersions::Version.last(VestalVersions::Version.count - ChronusVersion.count).collect(&:id)
      scope = VestalVersions::Version.where(id: delta_ids)
    else
      scope = VestalVersions::Version
    end
    scope.find_each do |vestal_version|
      chronus_versions << [vestal_version.versioned_id, vestal_version.versioned_type, ChronusVersion::Events::UPDATE, vestal_version.modifications.to_yaml, vestal_version.created_at, vestal_version.updated_at, vestal_version.source_audit_key]
      if chronus_versions.size >= batch_size
        ChronusVersion.import columns, chronus_versions, validate: false
        chronus_versions = []
      end
    end
    ChronusVersion.import columns, chronus_versions, validate: false
    ActiveRecord::Base.connection.execute("UPDATE chronus_versions SET source_audit_key = whodunnit WHERE whodunnit IS NOT NULL;")
    ChronusVersion.where.not(whodunnit: nil).update_all(whodunnit: nil)
    ChronusVersion.record_timestamps = true
    puts Time.now - start_time
  end
end