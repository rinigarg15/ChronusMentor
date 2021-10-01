# Skip match-indexing in tests by redefining the methods

#module Matching
#  class << self
#    def perform_full_index_and_refresh
#    end

#    def perform_program_delta_index_and_refresh(program_id)
#    end

#    def perform_users_delta_index_and_refresh(user_ids, program_id, options = {})
#    end

#    def remove_user(user_id, program_id)
#    end
#  end
#end

module AnalyticsHelper
  def render_gtac(track_info = nil)
  end
end