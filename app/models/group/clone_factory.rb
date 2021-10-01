# clones group by given parameters
#
# usage:
#   factory = Group::CloneFactory.new(source_group, program: program)
#   new_group = factory.clone

class Group::CloneFactory
  attr_reader :source, :clone, :options

  def initialize(source, options = {})
    @source = source
    # clone for the same program if not given
    @options = options
    @program = options[:program] || @source.program
    # clone it
    make_clone
  end

  protected

  def make_clone
    clone_group
    clone_memberships
  end

  def clone_group
    @clone = @program.groups.build
    @clone.name = @source.name
    @clone.mentoring_model = @source.mentoring_model if @options[:clone_mentoring_model]
  end

  def clone_memberships
    if @options[:bulk_duplicate]
      @clone.mentors = @source.mentors
      @clone.students = @source.students
      @clone.custom_users = @source.custom_users
      @source.custom_memberships.each do |source_custom_membership|
        @clone.custom_memberships.find{ |clone_custom_membership| clone_custom_membership.user_id == source_custom_membership.user_id }.role_id = source_custom_membership.role_id
      end
    else
      @clone.memberships = @source.memberships.map(&:dup)
    end
  end

end