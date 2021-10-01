# Sample Illustration:

# 1.List of members in a group

#   Gurus (1) Dhiwahar Admin
#   Sishyas (1) Dhiwa Mentee II
#   Refrees (1) Dhiwa Advisor

# 2.List of operations/updates

#   Adding Dhiwa XXIX as Sishya providing option 0
#   Replacing  Dhiwa Advisor with amrit sahoo as Refree
#   Removing  Dhiwa Mentee II as Sishya providing option 1

# 3.Input format of Client Request

#   {"connection"=>{"users"=>
#   {"48032"=>{"2595"=>{"'id'"=>"", "'role_id'"=>"2595", "'action_type'"=>"", "'option'"=>"", "'replacement_id'"=>""}},
#   "48036"=>{"2596"=>{"'id'"=>"48036", "'role_id'"=>"2596", "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}},
#   "52835"=>{"4309"=>{"'id'"=>"52835", "'role_id'"=>"4309", "'action_type'"=>"REPLACE", "'option'"=>"", "'replacement_id'"=>"49254"}},
#   "48566"=>{"2596"=>{"'id'"=>"48566", "'role_id'"=>"2596", "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}}}}}

# 4.Output format of "split_users_by_roles_and_options" method

#   [new_mentors, new_students, options]

#   new_mentors = array of user objects representing the updated set of mentors [48032]
#   new_students = array of user objects representing the updated set of mentees [48566]
#   options = {
#         other_roles_hash: a hash in format {other_role_object (Refree role) => array of user objects representing this role in group [49254]},
#         new_members_with_no_default_tasks: [ ] (arrays if ids of users added with this option),
#         removed_members_with_tasks_removed: [48036] (arrays if ids of users removed with this option),
#         replaced_members_list: {52835=>49254} (hash with key as replaced user id and value as replacement id)
#   }

class GroupUserSplitter

  attr_accessor :program, :group, :params_users

  attr_accessor :new_mentors, :new_students, :other_users, :other_roles_hash, :members_with_role, :mentoring_roles

  attr_accessor :new_members_with_no_default_tasks, :removed_members_with_tasks_removed, :replaced_members_list

  def initialize(program, group, params_users)
    self.program      = program
    self.group        = group
    self.params_users = params_users

    self.members_with_role = {}
    self.new_mentors      = []
    self.new_students     = []
    self.other_users      = []
    self.other_roles_hash = {}
    self.mentoring_roles  = []

    self.new_members_with_no_default_tasks  = []
    self.removed_members_with_tasks_removed = []
    self.replaced_members_list              = {}

    capture_current_snapshot!
  end

  def split_users_by_roles_and_options

    # looping through all the params posted
    # User can have multiple user_options as he can act as either of the roles allowed for a group
    (self.params_users || []).each{|user| process_user!(user)}

    options = {
      other_roles_hash:                   self.other_roles_hash,
      new_members_with_no_default_tasks:  self.new_members_with_no_default_tasks,
      removed_members_with_tasks_removed: self.removed_members_with_tasks_removed,
      replaced_members_list:              self.replaced_members_list
    }

    return [self.new_mentors, self.new_students, options]
  end

  def capture_current_snapshot!
    self.mentoring_roles        = self.program.roles.for_mentoring

    self.mentoring_roles.each do |role|
      self.members_with_role[role.id] = @group.memberships.where(role_id: role.id).pluck(:user_id)
    end
    
    old_members_by_role         = self.group.members_by_role
    self.new_mentors            = old_members_by_role[:mentors]
    self.new_students           = old_members_by_role[:mentees]
    self.other_users            = old_members_by_role[:other_users]

    self.other_roles_hash       = build_other_roles_hash_for_group_members
  end

  def process_add!(user_options)
    return if existing_member?(user_options)

    handle_new_with_no_default_task!(user_options)

    role = get_role(user_options)
    add_based_on_role(role, user_options, :id)
  end

  def process_remove!(user_options)
    return unless existing_member?(user_options)

    handle_remove_with_tasks_removed!(user_options)

    role = get_role(user_options)
    remove_based_on_role(role, user_options, :id)
  end

  def process_replace!(user_options)
    role = get_role(user_options)
    # We do not create default tasks from template for replacements
    self.replaced_members_list = self.replaced_members_list.merge({user_options["'id'"].to_i => user_options["'replacement_id'"].to_i})

    remove_based_on_role(role, user_options, :id)
    add_based_on_role(role, user_options, :replacement_id)
  end

  def get_user(user_options, user_id)
    self.program.users.find(user_options["'#{user_id}'"].to_i)
  end

  def add_action?(user_options)
    user_options["'action_type'"] == Group::MemberUpdateAction::ADD
  end

  def remove_action?(user_options)
    user_options["'action_type'"] == Group::MemberUpdateAction::REMOVE
  end

  def replace_action?(user_options)
    user_options["'action_type'"] == Group::MemberUpdateAction::REPLACE
  end

  def get_role(user_options)
    self.mentoring_roles.find(user_options["'role_id'"].to_i)
  end

  def existing_member?(user_options)
    self.members_with_role[user_options["'role_id'"].to_i].include?(user_options["'id'"].to_i)
  end

  def handle_new_with_no_default_task!(user_options)
    if user_options["'option'"].to_i == Group::AddOption::NO_TASK
      self.new_members_with_no_default_tasks << user_options["'id'"].to_i
    end
  end

  def handle_remove_with_tasks_removed!(user_options)
    if user_options["'option'"].to_i == Group::RemoveOption::REMOVE_TASKS
      self.removed_members_with_tasks_removed << user_options["'id'"].to_i
    end
  end

  def process_user!(user)
    user.second.values.each do |user_options|
      if add_action?(user_options)
        process_add!(user_options)
      elsif remove_action?(user_options)
        process_remove!(user_options)
      elsif replace_action?(user_options)
        process_replace!(user_options)
      end
    end
  end

  def add_based_on_role(role, user_options, user_id)
    user = get_user(user_options, user_id)
    if role.mentor?
      self.new_mentors << user
    elsif role.mentee?
      self.new_students << user
    else
      self.other_roles_hash[role] << user
    end
  end

  def remove_based_on_role(role, user_options, user_id)
    user = get_user(user_options, user_id)
    if role.mentor?
      self.new_mentors.delete(user)
    elsif role.mentee?
      self.new_students.delete(user)
    else
      self.other_roles_hash[role].delete(user)
    end
  end

 # For custom roles other than mentor and mentee, the method below will return a hash in the format: {role1=> [member1, member2, ...], role2 => [memberx, membery, memberz, ...], ...}

  def build_other_roles_hash_for_group_members
    mentoring_roles =  self.program.roles.for_mentoring
    mentoring_roles.each do |role|
      next if role.mentor? || role.mentee?
      self.other_roles_hash[role] = []
      members_with_role = self.group.memberships.where(role_id: role.id)
      members_with_role.each do |membership|
        self.other_roles_hash[role] << membership.user
      end
    end
    self.other_roles_hash
  end
end