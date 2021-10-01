# == Schema Information
#
# Table name: connection_membership_state_changes
#
#  id                       :integer          not null, primary key
#  connection_membership_id :integer
#  group_id                 :integer
#  user_id                  :integer
#  info                     :text(65535)
#  date_id                  :integer
#  date_time                :datetime
#  role_id                  :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#

class ConnectionMembershipStateChange < ActiveRecord::Base
  belongs_to :connection_membership, class_name: "Connection::Membership"
  belongs_to :group
  belongs_to :user
  belongs_to :role

  validates :connection_membership_id, :group_id, :user_id, :date_id, :info, presence: true

  after_save :es_reindex_user

  def set_info(hsh)
    self.info = hsh.to_yaml.gsub(/--- \n/, "")
  end

  def info_hash(force_refresh = false)
    @info_hash = (force_refresh || @info_hash.nil?) ? ActiveSupport::HashWithIndifferentAccess.new(YAML.load(self.info)) : @info_hash
  end

  def group_from_state
    self.info_hash[:group][:from_state].to_i
  end

  def group_to_state
    self.info_hash[:group][:to_state].to_i
  end

  def user_from_state
    self.info_hash[:user][:from_state]
  end

  def user_to_state
    self.info_hash[:user][:to_state]
  end

  def cm_from_state
    self.info_hash[:connection_membership][:from_state]
  end

  def cm_to_state
    self.info_hash[:connection_membership][:to_state]
  end

  def self.es_reindex(connection_membership_state_change)
    DelayedEsDocument.do_delta_indexing(User, Array(connection_membership_state_change), :user_id)
  end

  private

  def es_reindex_user
    # Elasticsearch delta indexing should happen in es_reindex method so that indexing for update_column/update_all or delete/delete_all will be taken care.
    self.class.es_reindex(self)
  end
end