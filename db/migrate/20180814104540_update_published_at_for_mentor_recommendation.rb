class UpdatePublishedAtForMentorRecommendation < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      MentorRecommendation.reset_column_information
      DelayedEsDocument.skip_es_delta_indexing {
        MentorRecommendation.where(status: MentorRecommendation::Status::PUBLISHED).update_all("published_at = updated_at")
      }
    end
  end

  def down
    # do nothing
  end
end
