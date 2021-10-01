module Push
  module Notifications
    class MentorOfferPushNotification < Push::Base

      HANDLED_NOTIFICATIONS = [
        PushNotification::Type::MENTOR_OFFER,
        PushNotification::Type::MENTOR_OFFER_ACCEPTED,
        PushNotification::Type::MENTOR_OFFER_REJECTED
      ]

      VALIDATION_CHECKS = {
        user_states: [User::Status::ACTIVE, User::Status::PENDING],
        check_for_features: [FeatureName::OFFER_MENTORING]
      }

      NOTIFICATION_LEVEL = PushNotification::Level::PROGRAM

      def recipients
        case self.notification_type
        when PushNotification::Type::MENTOR_OFFER
          [self.ref_obj.student]
        when PushNotification::Type::MENTOR_OFFER_ACCEPTED, PushNotification::Type::MENTOR_OFFER_REJECTED
          [self.ref_obj.mentor]
        end
      end

      def redirection_path
        case self.notification_type
        when PushNotification::Type::MENTOR_OFFER
          mentor_offers_url(get_common_url_options)
        when PushNotification::Type::MENTOR_OFFER_ACCEPTED
          group_url(self.ref_obj.group, get_common_url_options)
        when PushNotification::Type::MENTOR_OFFER_REJECTED
          users_url(get_common_url_options.merge(view: RoleConstants::STUDENT_NAME))
        end
      end

      def generate_message_for(locale)
        key = "push_notification.mentor_offer."
        GlobalizationUtils.run_in_locale(locale) do
          attributes_hash = { subprogram_or_program_name: self.ref_obj.program.name }
          case self.notification_type
          when PushNotification::Type::MENTOR_OFFER
            key << "offered"
            attributes_hash.merge!({
                         mentor_name: self.ref_obj.mentor.name(name_only: true),
              customized_mentor_term: self.ref_obj.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term_downcase
            })
          when PushNotification::Type::MENTOR_OFFER_ACCEPTED
            key << "accepted"
            attributes_hash.merge!({
                         mentee_name: self.ref_obj.student.name(name_only: true),
              customized_mentee_term: self.ref_obj.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term_downcase
            })
          when PushNotification::Type::MENTOR_OFFER_REJECTED
            key << "rejected"
            attributes_hash.merge!({
                            mentee_name: self.ref_obj.student.name(name_only: true),
              customized_mentoring_term: self.ref_obj.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase,
                customized_mentees_term: self.ref_obj.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term_downcase
            })
          end
          key.translate(attributes_hash)
        end
      end

    end
  end
end