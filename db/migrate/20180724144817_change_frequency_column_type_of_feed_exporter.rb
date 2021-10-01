class ChangeFrequencyColumnTypeOfFeedExporter < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :feed_exporters do |t|
        t.change_column :frequency, "int(11) DEFAULT #{FeedExporter::Frequency::WEEKLY} NOT NULL"
      end
    end

    ChronusMigrate.data_migration(has_downtime: false) do
      FeedExporter.where(frequency: 1).update_all(frequency: FeedExporter::Frequency::DAILY)
      FeedExporter.where.not(frequency: FeedExporter::Frequency::DAILY).update_all(frequency: FeedExporter::Frequency::WEEKLY)

      Delayed::Job.where("handler LIKE '%FeedExporterJob%'").destroy_all
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :feed_exporters do |t|
        t.change_column :frequency, "float DEFAULT 1.0"
      end
    end

    ChronusMigrate.data_migration(has_downtime: false) do
      FeedExporter.where(frequency: FeedExporter::Frequency::WEEKLY).update_all(frequency: 7.0)
      FeedExporter.where(frequency: FeedExporter::Frequency::DAILY).update_all(frequency: 1.0)
    end
  end
end