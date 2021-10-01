# == Schema Information
#
# Table name: recent_activities
#
#  id              :integer          not null, primary key
#  member_id       :integer
#  ref_obj_id      :integer
#  ref_obj_type    :string(255)
#  created_at      :datetime
#  updated_at      :datetime
#  action_type     :integer          not null
#  for_id          :integer
#  target          :integer          not null
#  organization_id :integer
#  message         :text(65535)
#

# === Explanation of the fields
# * <tt>user</tt>         : the user involved in the activity (typically the activity doer)
# * <tt>for</tt>          : whom this record belongs to (whom this record should be shown to)
#                           in case of RecentActivityConstants::Target::USER type activities
# * <tt>target</tt>       : The audience of the RA. (Mentors or Mentees or Admins or
#                           All or an invidivual user)
# * <tt>ref_obj</tt>      : Reference to the activity object (polymorphic)
# * <tt>action_type</tt>  : The type of the activity
class RecentActivity < ActiveRecord::Base

  module ScopeConditions
    # Admin should get all public recent activities and activities for self
    ADMIN = Proc.new do |user|
      {
        # One importatnt point to note here is that the AbstractRequest.to_s is used to refer to mentor request
        # Do not worry that it is wrong :P, rails stores the base class for polymorphic associations.
        # Rails resolves the STI relationship with polymorphic association in this manner.
        :conditions => ["(program_activities.program_id = ?) AND (for_id = ? OR for_id IS NULL OR ref_obj_type in (?) OR member_id = ?)",
                        user.program_id, user.member_id, [AbstractRequest.to_s, MentorOffer.to_s], user.member_id]
      }
    end
  
    # Mentors should public recent activities sent to all or mentors and activities for self
    MENTOR = Proc.new do |user|
      all = RecentActivityConstants::Target::ALL
      mentors = RecentActivityConstants::Target::MENTORS
      {
        :conditions => ["(program_activities.program_id = ?) AND (for_id = ? OR target IN (?) OR member_id = ?)",
                        user.program_id, user.member_id, [all, mentors], user.member_id]
      }
    end
  
    # Mentees should public recent activities sent to all or mentees and activities for self
    MENTEE = Proc.new do |user|
      all = RecentActivityConstants::Target::ALL
      students = RecentActivityConstants::Target::MENTEES
      {
        :conditions => ["(program_activities.program_id = ?) AND (for_id = ? OR target IN (?) OR member_id = ?)",
                        user.program_id, user.member_id, [all, students], user.member_id]
      }
    end
  
    # Users belonging to both mentor and mentee categories should get all the RAs
    MENTOR_MENTEE = Proc.new do |user|
      all = RecentActivityConstants::Target::ALL
      students = RecentActivityConstants::Target::MENTEES
      mentors = RecentActivityConstants::Target::MENTORS
      {
        :conditions => ["(program_activities.program_id = ?) AND (for_id = ? OR target IN (?) OR member_id = ?)",
                        user.program_id, user.member_id, [all, students, mentors], user.member_id]
      }
    end

    # non administrative non default role
    OTHER_NON_ADMINISTRATIVE_ROLE = Proc.new do |user|
      all = RecentActivityConstants::Target::ALL
      other_non_administrative_roles = RecentActivityConstants::Target::OTHER_NON_ADMINISTRATIVE_ROLES
      {
        :conditions => ["(program_activities.program_id = ?) AND (for_id = ? OR target IN (?) OR member_id = ?)",
                        user.program_id, user.member_id, [all, other_non_administrative_roles], user.member_id]
      }
    end

    # If no role then user should get activities targeted to all users
    ALL =  Proc.new do |user|
      all = RecentActivityConstants::Target::ALL
      {
        :conditions => ["(program_activities.program_id = ?) AND (for_id = ? OR target IN (?) OR member_id = ?)",
                        user.program_id, user.member_id, [all], user.member_id]
      }
    end
  end

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  has_many  :program_activities,
            :foreign_key => 'activity_id',
            :dependent => :destroy

  has_many  :programs,
            :through => :program_activities

  has_many :connection_activities,
           :dependent => :destroy,
           :class_name => "Connection::Activity"

  belongs_to :for, :class_name => "Member"
  belongs_to :member
  belongs_to_organization :foreign_key => 'organization_id'
  belongs_to :ref_obj, :polymorphic => true


  scope :recent_activity_for, -> (role_condition, *role_condition_data) { includes(:program_activities).where(role_condition, *role_condition_data).references(:program_activities).order("recent_activities.id DESC") }

  scope :for_display, -> { where("target != ?", RecentActivityConstants::Target::NONE)}

  # Activities performed by the given member.
  scope :by_member, ->(member) { where({:member_id => member.id})}

  # Scopes to the activities of the given type.
  scope :of_type, ->(act_type) {
    where({:action_type => act_type})
  }

  # Scopes to the activities of not the given type.
  scope :not_of_types, ->(act_types) {
    where(["action_type NOT IN (?)", act_types])
  }

  # Scopes to +limit+ number of records.
  scope :with_length, ->(limit) { limit(limit)}

  # Scopes to records having id below +offset+
  scope :with_upper_offset, ->(offset) {
    where(["recent_activities.id < ?", offset])
  }

  # Order by latest activity first.
  scope :latest_first, -> { order("recent_activities.id DESC") }

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates_presence_of :action_type, :target

  validates_inclusion_of :action_type, in: RecentActivityConstants::Type.all

  validates_inclusion_of :target,
    :in => (RecentActivityConstants::Target::ALL..RecentActivityConstants::Target::OTHER_NON_ADMINISTRATIVE_ROLES)

  validate :check_for_id_and_target

  ##############################################################################
  # CALLBACKS
  ##############################################################################

  after_create :create_connection_activity
  
  ##############################################################################
  # INSTANCE METHODS
  ##############################################################################

  def self.for_admin(user)
    role_condition, *role_condition_data = ScopeConditions::ADMIN.call(user)[:conditions]
    recent_activity_for(role_condition, *role_condition_data)
  end

  def self.for_mentor(user)
    role_condition, *role_condition_data = ScopeConditions::MENTOR.call(user)[:conditions]
    recent_activity_for(role_condition, *role_condition_data)
  end

  def self.for_student(user)
    role_condition, *role_condition_data = ScopeConditions::MENTEE.call(user)[:conditions]
    recent_activity_for(role_condition, *role_condition_data)
  end

  def self.for_mentor_and_student(user)
    role_condition, *role_condition_data = ScopeConditions::MENTOR_MENTEE.call(user)[:conditions]
    recent_activity_for(role_condition, *role_condition_data)
  end

  def self.for_other_non_administrative_roles(user)
    role_condition, *role_condition_data = ScopeConditions::OTHER_NON_ADMINISTRATIVE_ROLE.call(user)[:conditions]
    recent_activity_for(role_condition, *role_condition_data)
  end

  def self.for_all(user)
    role_condition, *role_condition_data = ScopeConditions::ALL.call(user)[:conditions]
    recent_activity_for(role_condition, *role_condition_data)
  end

  def self.destroy_all_belonging_to_connection_memberships(group_id, member_ids_of_deleted_memberships)
    scraps = Scrap.where(ref_obj_id: group_id, sender_id: member_ids_of_deleted_memberships, ref_obj_type: Group.to_s)
    scraps.each do |scrap|
      self.where(ref_obj_id: scrap.id, ref_obj_type: AbstractMessage.name).destroy_all
    end
  end

  # Returns the user in the program for the activity
  def get_user(program)
    program_id = program.is_a?(Program) ? program.id : program
    self.member.users.find{|user| user.program_id == program_id} if self.member
  end

  # Returns true if the RA is published in more than one program.
  # AC_FIXME
  def for_multiple_programs?
    self.programs.count > 1
  end

  private

  # <tt>for</tt> must be present iff target is RecentActivityConstants::Target::USER
  def check_for_id_and_target
    if (target == RecentActivityConstants::Target::USER) && !for_id ||
      (target != RecentActivityConstants::Target::USER) && for_id
      errors[:base] << "for_id and target incompatible"
    end
  end
  
  # Creates Connection::Activity for activities of type in
  # Connection::Activity::SUPPORTED_ACTIVITIES
  #
  # RA_TODO Add Task related activities
  #
  def create_connection_activity
    if Connection::Activity::SUPPORTED_ACTIVITIES.include?(self.action_type)
      if [

          RecentActivityConstants::Type::VISIT_MENTORING_AREA,
          RecentActivityConstants::Type::GROUP_REACTIVATION,
          RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE,
          RecentActivityConstants::Type::GROUP_MEMBER_ADDITION,
          RecentActivityConstants::Type::GROUP_MEMBER_REMOVAL,
          RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION,
          RecentActivityConstants::Type::GROUP_MEMBER_LEAVING,
          RecentActivityConstants::Type::GROUP_TERMINATING,
          RecentActivityConstants::Type::GROUP_MEMBER_ADDITION_REMOVAL,
          RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY

        ].include?(self.action_type)
        group = self.ref_obj
      elsif self.action_type == RecentActivityConstants::Type::GROUP_PRIVATE_NOTE_CREATION
        group = self.ref_obj.connection_membership.group
      elsif self.action_type == RecentActivityConstants::Type::COACHING_GOAL_ACTIVITY_CREATION
        group = self.ref_obj.coaching_goal.group
      else  
        # For all activities other than visit mentoring area, the ref_obj is the
        # task or scrap. Get the Group from it.
        return if self.ref_obj.is_a?(Scrap) && self.ref_obj.is_meeting_message?
        group = self.ref_obj.is_a?(Scrap) ? self.ref_obj.ref_obj : self.ref_obj.group
      end

      Connection::Activity.create!(:group => group, :recent_activity => self) unless group.nil?
    end
  end
end
