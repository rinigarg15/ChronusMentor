namespace :single_time do

  #usage: bundle exec rake single_time:cleanup_duplicate_bulk_matches
  desc "Cleanup duplicate bulk matches and bulk recommendations"
  task cleanup_duplicate_bulk_matches: :environment do
    Common::RakeModule::Utils.execute_task do
      duplicate_bulk_matches = AbstractBulkMatch.order(updated_at: :desc).group_by{|bm| [bm.program_id, bm.type] }.select{|_k, v| v.size > 1 }
      valid_bulk_match_ids = []
      deleted_bulk_match_ids = []
      programs = Program.where(id: duplicate_bulk_matches.keys.transpose[0]).index_by(&:id)
      duplicate_bulk_matches.each do |program_id_with_type, bulk_matches|
        program_id = program_id_with_type[0]
        type = program_id_with_type[1]
        valid_bulk_match, to_be_deleted = collect_valid_and_to_be_deleted_list(bulk_matches)
        is_default = valid_bulk_match.default

        to_be_deleted.each do |dup_bm|
          is_default = 1 if dup_bm.default == 1
          programs[program_id].groups.where(bulk_match_id: dup_bm.id).update_all(bulk_match_id: valid_bulk_match.id, skip_delta_indexing: true) if type == BulkMatch.name
          deleted_bulk_match_ids << dup_bm.id
          dup_bm.delete
        end
        valid_bulk_match_ids << valid_bulk_match.id
        valid_bulk_match.update_attributes!(default: is_default)
      end
      Common::RakeModule::Utils.print_success_messages("Valid Abstract Bulk Match Ids: #{valid_bulk_match_ids}")
      Common::RakeModule::Utils.print_success_messages("Deleted Abstract Bulk Match Ids: #{deleted_bulk_match_ids}")
    end
  end


  private

  def collect_valid_and_to_be_deleted_list(bulk_matches)
    to_be_deleted = []
    valid_bulk_match = nil
    bulk_matches.each do |bm|
      if valid_bulk_match.nil? && bm.mentor_view.present? && bm.mentee_view.present?
        valid_bulk_match = bm
      else
        to_be_deleted << bm
      end
    end
    [valid_bulk_match, to_be_deleted]
  end

end

