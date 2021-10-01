# https://chronus.atlassian.net/browse/AP-16787

class RakeClearSurveyResponsesForCff< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        organization = Program::Domain.get_organization("cfpeerconnect.com", nil)
        program = organization.programs.find_by(root: "p1")
        survey = program.surveys.of_engagement_type.find(8742)

        survey_answer_ids = []
        survey.responses.each do |_, survey_answers|
          survey_answer = survey_answers.first
          user = survey_answer.user
          group = survey_answer.group
          membership = group.membership_of(user)
          if membership.is_a?(Connection::MentorMembership)
            survey_answer_ids << survey_answers.map(&:id)
          end
        end

        SurveyAnswer.where(id: survey_answer_ids.flatten).destroy_all
      end
    end
  end

  def down
  end
end