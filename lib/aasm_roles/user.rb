module AasmRoles
  module User
    unless Object.constants.include? "STATEFUL_ROLES_CONSTANTS_DEFINED"
      STATEFUL_ROLES_CONSTANTS_DEFINED = 'yup' # sorry for the C idiom
    end

    def self.included(recipient)
      recipient.connection
      recipient.class_eval do
        include AASM

        aasm column: 'state', whiny_transitions: false do
          state :active
          state :suspended
          state :deleted
          state :pending

          event :activate do
            transitions from: [:active, :suspended, :deleted], to: :active
          end

          event :suspend do
            transitions from: [:active, :pending], to: :suspended
          end

          event :delete do
            transitions from: [:active], to: :deleted
          end
        end
      end
    end
  end
end