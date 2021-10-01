# == Schema Information
#
# Table name: group_state_changes
#
#  id         :integer          not null, primary key
#  group_id   :integer
#  from_state :string(255)
#  to_state   :string(255)
#  date_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class GroupStateChange < ActiveRecord::Base
  include GroupStateChangeElasticsearchQueries
  include GroupStateChangeElasticsearchSettings

  belongs_to :group

  validates :group_id, :date_id, :to_state, presence: true
  validates :from_state, :to_state, inclusion: {in: (Group::Status.all.map{|state| [state, state.to_s]}.flatten + [nil])}

  after_save :es_reindex_group

  def self.es_reindex(group_state_change)
    DelayedEsDocument.do_delta_indexing(Group, Array(group_state_change), :group_id)
  end

  private

  def es_reindex_group
    # Elasticsearch delta indexing should happen in es_reindex method so that indexing for update_column/update_all or delete/delete_all will be taken care.
    self.class.es_reindex(self)
  end
end
