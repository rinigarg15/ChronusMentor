# These are configs required for the generic kendo presenter. Ideally, we should parse this and create a hash and pass it to the initializekendo hash! #notime
module GenericKendoPresenterConfigs
  module ProgramInvitationGrid
    CONFIG = {
      :attributes => {
        :sent_to => {
          :filterable => true,
          :type => :string
        },
        :expires_on => {
          :filterable => true,
          :type => :datetime
        },
        :sent_on => {
          :filterable => true,
          :type => :datetime
        },
        :statuses => {
          :custom_filter => Proc.new{|filter| ProgramInvitation::KendoScopes.status_filter(filter)},
          :filterable => true
        },
        :roles_name => {
          :custom_sort => Proc.new{|dir| ProgramInvitation::KendoScopes.roles_sort(dir)},
          :custom_filter => Proc.new{|filter| ProgramInvitation::KendoScopes.roles_filter(filter)},
          :filterable => true
        },
        :sender => {
          :custom_sort => Proc.new{|dir| ProgramInvitation::KendoScopes.sender_sort(dir)},
          :custom_filter => Proc.new{|dir| ProgramInvitation::KendoScopes.sender_filter(dir)},
          :filterable => true
        }
      },
      :default_scope => nil
    }

    def self.get_config(program, sent_by_admin = false)
      
      scope = get_invitations(program, sent_by_admin)
      CONFIG.merge(:default_scope => scope)
    end

    def self.get_invitations(program, sent_by_admin = false)
      admin_user_ids = program.admin_users.pluck(:id)
      program_invitation_ids_sent_by_admin = program.program_invitations.where(:user_id => admin_user_ids).pluck(:id)

      sent_by_admin ? program.program_invitations.where(:id => program_invitation_ids_sent_by_admin) : program.program_invitations.where("program_invitations.id NOT IN (?)", program_invitation_ids_sent_by_admin)
    end

  end

  module CheckinGrid
    CONFIG = {
      :attributes => {
        :mentor => {
          :filterable => true,
          :custom_sort => Proc.new{|dir| GroupCheckin::KendoScopes.sort_mentors(dir)},
          :custom_filter => Proc.new{|filter| GroupCheckin::KendoScopes.filter_mentors(filter)},
          :type => :string
        },
        :group => {
          :filterable => true,
          :custom_sort => Proc.new{|dir| GroupCheckin::KendoScopes.sort_groups(dir)},
          :custom_filter => Proc.new{|filter| GroupCheckin::KendoScopes.filter_groups(filter)},
          :type => :string
        },
        :type => {
          :filterable => true,
          :custom_sort => Proc.new{|dir| GroupCheckin::KendoScopes.sort_type(dir)},
          :custom_filter => Proc.new{|filter| GroupCheckin::KendoScopes.filter_type(filter)},
          :type => :string
        },
        :comment => {
          :filterable => true,
          :type => :string
        },
        :title => {
          :filterable => true,
          :type => :string
        },
        :date => {
          :filterable => true,
          :custom_filter => Proc.new{|filter| GroupCheckin::KendoScopes.filter_dates(filter)},
          :type => :datetime,
        },
        :duration => {
          :filterable => false,
          :type => :string
        },
        :user => {
          :filterable => true,
          :custom_filter => Proc.new{|filter| GroupCheckin::KendoScopes.filter_user(filter)},
          :type => :string
        }
      },
      :default_scope => nil
    }

    def self.get_config(scope)
      CONFIG.merge(:default_scope => scope)
    end

  end

end