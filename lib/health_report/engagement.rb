module HealthReport
  class Engagement < CumulativeReport
    # Base time from now in retrospect, which we use to fetch data for all the
    # computations.
    DATA_PERIOD = 1.month

    POSTS_THRESHOLD = 4
    POSTS_MINIMUM = 0
    POSTS_MAXIMUM = 10

    GOALS_THRESHOLD = 1
    GOALS_MINIMUM = 0
    GOALS_MAXIMUM = 10

    ACTIVE_CONNECTIONS_THRESHOLD = 0.7
    OVERALL_SATISFACTION = 0.7
    CONNECTION_MODES = ['Online', 'Chat', 'Phone', 'Email', 'Face_to_Face']

    # Map from question we show to the end users, to what we call it while reporting.
    # Like,
    #   'Mentoring Area' => 'Online'
    #   'Face to face meetings' =>'Face-to-Face'
    #
    QUESTION_TEXT_TO_MODE_MAP = {
      'Mentoring Area'        => 'Online',
      'Chat/IM'               => 'Chat',
      'Phone'                 => 'Phone',
      'Emails'                => 'Email',
      'Face to face meetings' => 'Face_to_Face'
    }

    attr_accessor :program, :post_history
    attr_accessor :posts_per_connection,
                  :active_connections,
                  :overall_satisfaction,
                  :connection_mode

    cumulative_metric :posts_per_connection,
                      :active_connections,
                      :overall_satisfaction

    # Constructor
    #
    # Params:
    # * <tt>program</tt> : Program to compute engagement metrics for.
    #
    def initialize(program)
      self.program = program
      self.post_history = HistoryMetric.new

      self.posts_per_connection = PercentMetric.new(POSTS_THRESHOLD, {
        :minimum => POSTS_MINIMUM,
        :maximum => POSTS_MAXIMUM,
        :unit => 'post'})

      self.active_connections = PercentMetric.new(ACTIVE_CONNECTIONS_THRESHOLD)
      self.overall_satisfaction = PercentMetric.new(OVERALL_SATISFACTION)
      self.connection_mode = DistributedMetric.new(CONNECTION_MODES)
    end

    def compute
      groups = self.program.groups.active
      group_ids = groups.pluck(:id)
      group_count = groups.count

      interactions_count = 0
      last_month_interactions_count = 0
      [fetch_scraps_count(group_ids), fetch_posts_count(group_ids)].each do |counts_array|
        interactions_count += counts_array[0]
        last_month_interactions_count += counts_array[1]
      end
      self.post_history.update_metric(interactions_count, last_month_interactions_count)

      if group_count.zero?
        self.posts_per_connection.update_metric(nil)
      else
        self.posts_per_connection.update_metric(last_month_interactions_count / group_count.to_f)
      end

      if self.program.connection_feedback_enabled?
        if group_count.zero?
          self.active_connections.update_metric(nil)
        else
          active_groups_count = self.program.groups.with_status(Group::Status::ACTIVE).count
          self.active_connections.update_metric(active_groups_count / group_count.to_f)
        end
        update_overall_satisfaction
        update_connection_mode
      end
    end

    private

    # Processes all feedback responses and computes the average satisfaction
    # question (first question)
    def update_overall_satisfaction
      answers = get_feedback_answers_for(CommonQuestion::Mode::EFFECTIVENESS)
      if !answers.present?
        # No data.
        self.overall_satisfaction.update_metric(nil)
      else
        # Convert the feedback answer to a scale of 0 to 1.
        num_levels = SurveyConstants::EFFECTIVENESS_LEVELS.size
        # Numeric difference between each level's value.
        level_delta = 1 / (num_levels - 1).to_f
        level_to_value_map = {}

        0.upto(num_levels - 1) do |level_num|
          level_to_value_map[SurveyConstants::EFFECTIVENESS_LEVELS[level_num].to_s] =
            1 - (level_num * level_delta)
        end

        total_satisfaction = answers.collect{|a| level_to_value_map[a.answer_value]}.sum
        average_satisfaction = total_satisfaction / answers.size.to_f
        self.overall_satisfaction.update_metric(average_satisfaction)
      end
    end

    def update_connection_mode
      answers = get_feedback_answers_for(CommonQuestion::Mode::CONNECTIVITY)
      # No need to update if there is no data.
      if answers.present?
        # Get all the answered choices and group them.
        answered_modes = answers.collect(&:answer_value).flatten
        grouped_modes = answered_modes.group_by{|ans_text| ans_text}

        # Map from answer text to the number of times it was given.
        answer_map = {}
        grouped_modes.each do |mode, occurrences|
          answer_map[mode] = occurrences.size
        end

        total_occurrences = answer_map.values.sum
        distribution_map = {}
        answer_map.each do |mode, occurrence_count|
          # Convert answers to the reporting format and find the share of
          # the answer
          distribution_map[QUESTION_TEXT_TO_MODE_MAP[mode]] =
            occurrence_count / total_occurrences.to_f
        end

        self.connection_mode.update_metric(distribution_map)
      end
    end

    def get_feedback_answers_for(mode)
      feedback_survey = self.program.feedback_survey
      questions = feedback_survey.try(:survey_questions)
      if questions.present?
        question = questions.find_by(question_mode: mode)
        question.survey_answers if question.present?
      end
    end

    def fetch_scraps_count(group_ids)
      scraps = self.program.scraps.where(ref_obj_id: group_ids, ref_obj_type: Group.name)
      [scraps.count, scraps.where("messages.created_at > ?", DATA_PERIOD.ago).count]
    end

    def fetch_posts_count(group_ids)
      forum_ids = self.program.forums.where(group_id: group_ids)
      topic_ids = self.program.topics.where(forum_id: forum_ids)
      posts = self.program.posts.where(topic_id: topic_ids)
      [posts.count, posts.where("posts.created_at > ?", DATA_PERIOD.ago).count]
    end
  end
end