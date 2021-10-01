# == Schema Information
#
# Table name: user_state_changes
#
#  id                         :integer          not null, primary key
#  user_id                    :integer
#  info                       :text(65535)
#  date_id                    :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  date_time                  :datetime
#  connection_membership_info :text(65535)
#

class UserStateChange < ActiveRecord::Base
  include UserStateChangeElasticsearchQueries
  include UserStateChangeElasticsearchSettings

  belongs_to :user

  validates :user_id, :date_id, :info, presence: true
  after_save :es_reindex_user

  def set_info(hsh)
    self.info = hsh.to_yaml.gsub(/--- \n/, "")
  end

  def info_hash(force_refresh = false)
    @info_hash = (force_refresh || @info_hash.nil?) ? ActiveSupport::HashWithIndifferentAccess.new(YAML.load(self.info)) : @info_hash
  end

  def set_connection_membership_info(hsh)
    self.connection_membership_info = hsh.to_yaml.gsub(/--- \n/, "")
  end

  def connection_membership_info_hash(force_refresh = false)
    @connection_membership_info_hash = (force_refresh || @connection_membership_info_hash.nil?) ? ActiveSupport::HashWithIndifferentAccess.new(YAML.load(self.connection_membership_info)) : @connection_membership_info_hash
  end

  def from_state
  	self.info_hash[:state][:from]
  end

  def to_state
  	self.info_hash[:state][:to]
  end

  def from_roles
    (self.info_hash[:role][:from]||[])
  end

  def to_roles
    (self.info_hash[:role][:to]||[])
  end

  def connection_membership_from_roles
    self.connection_membership_info_hash[:role][:from_role] == [] ? nil : self.connection_membership_info_hash[:role][:from_role]
  end

  def connection_membership_to_roles
    self.connection_membership_info_hash[:role][:to_role] == [] ? nil : self.connection_membership_info_hash[:role][:to_role]
  end

  def self.es_reindex(user_state_change)
    DelayedEsDocument.do_delta_indexing(User, Array(user_state_change), :user_id)
  end

  private

  def es_reindex_user
    # Elasticsearch delta indexing should happen in es_reindex method so that indexing for update_column/update_all or delete/delete_all will be taken care.
    self.class.es_reindex(self)
  end
end
