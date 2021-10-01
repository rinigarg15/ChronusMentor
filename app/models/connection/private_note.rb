# == Schema Information
#
# Table name: connection_private_notes
#
#  id                      :integer          not null, primary key
#  text                    :text(65535)
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  created_at              :datetime
#  updated_at              :datetime
#  ref_obj_id              :integer
#  type                    :string(255)
#

class Connection::PrivateNote < AbstractNote

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  belongs_to :connection_membership,
             :foreign_key => 'ref_obj_id',
             :class_name => 'Connection::Membership'

  has_one :owner,
          :through => :connection_membership,
          :source => :user,
          :class_name => 'User'


  ##############################################################################
  # VALIDATIONS
  ##############################################################################
  validates :connection_membership, presence: true
  
  ##############################################################################
  # CALLBACKS
  ##############################################################################

  after_create :create_activity

  ##############################################################################
  # NAMED SCOPES
  ##############################################################################

  # Notes owned by the given user.
  #
  # Using custom sql so as to get around with Duplicate join alias issue in
  # rails. This named scope is typically used along with Group#private_notes
  # association, which has it's own join with :connection_memberships. So,
  # when applying this on top of that gives raise to
  # 'Not unique table/alias connection_memberships' error.
  #
  # http://pivotallabs.com/users/stevend/blog/articles/521-pivots-patch-rails-named-scope-with-the-joins-can-cause-table-aliasing-issues
  #
  scope :owned_by, ->(user) {
    joins(
        "INNER JOIN connection_memberships AS note_memberships " +
        "ON note_memberships.id = connection_private_notes.ref_obj_id " +
        "INNER JOIN users ON users.id = note_memberships.user_id").where(["users.id = ?", user.id]).readonly(false)
  }

  # Notes on a given connection.
  scope :on_group, ->(group) {
    joins({:connection_membership => [:group]}).where(["groups.id = ?", group.id])
  }


  # Custom intializer for instantiating a new note for the user in the given
  # group, with the attributes. 
  def self.new_for(group, user, attributes)
    Connection::PrivateNote.new(
      attributes.merge(:connection_membership => group.membership_of(user)))
  end

  private

  # Creates a recent activity of type +GROUP_PRIVATE_NOTE_CREATION+.
  def create_activity
    RecentActivity.create!(
      :programs => [self.connection_membership.group.program],
      :action_type => RecentActivityConstants::Type::GROUP_PRIVATE_NOTE_CREATION,
      :member => self.owner.member,
      :target => RecentActivityConstants::Target::NONE,
      :ref_obj => self
    )
  end
end
