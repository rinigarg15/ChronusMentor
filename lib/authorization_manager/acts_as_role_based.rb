module AuthorizationManager
  # Provies role management support to models.
  #
  # Usage:
  #   class User
  #     acts_as_role_based :role_association => 'designation',
  #                        :validate_on => :create,
  #   end
  #
  module ActsAsRoleBased
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # Adds roles 'has_many' association to the model and accessors for the
      #   role through name for easy role management as follows
      #
      #   record.role_names #=> ['mentor', 'student']
      #   record.role_names #=> ['mentor', 'student']
      #
      # Also adds presence validation for the association by default.
      #
      # ==== Configuration options
      # * <tt>:role_association</tt> : name to refer the 'role' with. Say,
      #   'recipient'. Defaults to 'role'. The dynamic role name accessors
      #   methods will be generated based on this name as 'recipient_names' and
      #   'recipient_names='
      # * <tt>:validate_on</tt> : validation callback point - :save, :update or
      #   :create
      # * <tt>:skip_validation</tt> : skips the validation of role presence for
      #   this model
      # * <tt>:mentors_scope</tt> : named scope for mentors
      # * <tt>:students_scope</tt> : named scope for students
      # * <tt>:admins_scope</tt> : named scope for admins
      # * <tt>:program_assoc</tt> : association to get the program
      #
      def acts_as_role_based(opts = {})
        role_assoc = opts[:role_association] || 'role'
        plural_role_assoc = role_assoc.pluralize
        program_assoc = opts[:program_assoc] || 'program'

        # Add <i>plural_role_assoc</i> association through role_references table
        has_many :role_references, :dependent => :destroy, :as => :ref_obj
        role_assoc_options = { through: :role_references, source: :role }
        role_assoc_options.merge!({after_add: opts[:role_assoc_after_add]}) if opts[:role_assoc_after_add]
        role_assoc_options.merge!({after_remove: opts[:role_assoc_after_remove]}) if opts[:role_assoc_after_remove]
        role_assoc_options.merge!({before_remove: opts[:role_assoc_before_remove]}) if opts[:role_assoc_before_remove]
        has_many plural_role_assoc.to_sym, role_assoc_options

        # Validate the roles collection at the requested point.
        unless opts[:skip_validation]
          validate_options = {}
          validate_options[:on] = opts[:validate_on] if  opts[:validate_on]
          validate_options[:if] = opts[:validate_if] if  opts[:validate_if]
          validates_presence_of plural_role_assoc, validate_options
        end

        # Scope to Mentors
        scope((opts[:mentors_scope] || :for_mentors), -> {
          where("roles.name = ?", RoleConstants::MENTOR_NAME).joins(plural_role_assoc.to_sym).readonly(false)
        })

        # Scope to Students
        scope((opts[:students_scope] || :for_students), -> {
          where("roles.name = ?", RoleConstants::STUDENT_NAME).joins(plural_role_assoc.to_sym).readonly(false)
        })

        # Scope to admins
        scope((opts[:admins_scope] || :for_admins), -> {
          where("roles.name = ?", RoleConstants::ADMIN_NAME).joins(plural_role_assoc.to_sym).readonly(false)
        })

        # Scope to the given role(s).
        scope :for_role, Proc.new { |role_names|
          select("DISTINCT #{self.table_name}.*").where("roles.name IN (?)", role_names).joins(plural_role_assoc.to_sym).readonly(false)
        } do
          def count(options = {}); all.length end;
        end

        # Returns records that do not have given roles alone.
        scope :not_for_only_role, Proc.new { |role_names|
          select("DISTINCT #{self.table_name}.*").where("roles.name NOT IN (?)", role_names).joins(plural_role_assoc.to_sym).readonly(false)
        } do
          def count(options = {}); all.length; end;
        end

        self.class_eval do
          # Getter for role names
          define_method("#{role_assoc}_names") do
            self.send(plural_role_assoc).collect(&:name)
          end

          # Setter for roles via role names
          define_method("#{role_assoc}_names=") do |names|
            program = self.send(program_assoc)

            # Program must be set for the roles to be set from the role names.
            raise ProgramNotSetException if program.nil?
            return if names.blank?

            names = names.split(',') if names.is_a?(String)
            new_roles = names.collect{|n| program.get_role(n)}.compact
            self.send(plural_role_assoc + "=", new_roles)
          end

          # Comma separated role name string
          define_method("#{role_assoc}_names_str") do
            self.send("#{role_assoc}_names").join(',')
          end

          # Role names formatted to human readable string with program specific
          # mentor and mentee names.
          #
          #   ['mentor'] => 'mentor'
          #   ['admin','student'] => 'administrator and student'
          #   ['mentor','admin','student'] => 'mentor, administrator and student'
          #
          # ==== Params
          # * <tt>opts</tt>: options as accepted by RoleConstants.human_role_string
          #
          define_method("formatted_#{role_assoc}_names") do |*opts|
            options = opts.last.is_a?(Hash) ? opts.pop : {}

            # The program assocation can be either Program or an Organization.
            prog_or_org = self.send(program_assoc)
            RoleConstants.human_role_string(self.send("#{role_assoc}_names"), {:program => prog_or_org}.merge(options))
          end

          # Returns whether this record has *any* of the roles in
          # <i>role_name_list</i>
          define_method("has_any_#{role_assoc}?") do |role_list|
            (self.send("#{role_assoc}_names") & role_list.collect(&:name)).any?
          end

          define_method("recent_activity_target") do
            program = self.send(program_assoc)
            if (self.send("#{role_assoc}_names").count > 1) #Handled in RA helper as current RA architecture is not enough to handle this
              RecentActivityConstants::Target::ALL
            elsif self.send("#{role_assoc}_names").include?(RoleConstants::MENTOR_NAME)
              RecentActivityConstants::Target::MENTORS
            elsif self.send("#{role_assoc}_names").include?(RoleConstants::STUDENT_NAME)
              RecentActivityConstants::Target::MENTEES
            elsif (self.send("#{role_assoc}_names") & program.roles_without_admin_role.non_default.collect(&:name)).any?
              RecentActivityConstants::Target::OTHER_NON_ADMINISTRATIVE_ROLES
            else
              return
            end
          end
        end
      end
    end
  end
end
