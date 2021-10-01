module Matching
  # The Client interface to the matching service
  # 
  # The client is tied to a specific +Program+. It can be instantiated once and
  # used multiple times to get the mentor matches for different students.
  #
  # Usage:
  #   @client    = Matching::Client.new(@program)  #=> Creates a Matching::Client instance for the +@program+
  #   @results_1 = client.bulk_match(@student_ids, @mentor_ids)   #=> Updates cache of @students_ids for @mentor_ids
  #
  class Client
    # The +Program+ for which this client will be computing the match.
    attr_accessor :program

    # Instance of Matching::Service used for carrying out the matching.
    attr_accessor :service

    # Constructor.
    #
    # Params:
    # *<tt>program</tt> : the Program for which this client is used for.
    #
    def initialize(program, for_details = false)
      self.program = program
      self.service = Matching::Service.new(
        construct_configuration(for_details), :program => program
      )
    end

    def bulk_match(student_ids = [])
      self.service.bulk_match_complete(student_ids)
    end

    def bulk_mentee_match(student_ids = [], mentor_ids = [])
      self.service.delta_mentee_match(student_ids, mentor_ids)
    end

    def bulk_mentor_match(student_ids = [], mentor_ids = [])
      self.service.delta_mentor_match(student_ids, mentor_ids)
    end

    private

    #
    # Prepares the Matching::Configuration to use for the matching as per the
    # +MatchConfig+s of the program.
    #
    def construct_configuration(for_details)
      configuration = Matching::Configuration.new
      configs = for_details ? self.program.match_configs.with_label : self.program.match_configs
      # Add custom profile question configurations.
      configs.includes([:student_question => [:profile_question], :mentor_question => [:profile_question]]).find_each do |pair|
        configuration.add_mapping(
          [RoleQuestion, pair.mentor_question.question_text],
          [RoleQuestion, pair.student_question.question_text],
          [pair.weight, pair.threshold, pair.operator, pair.matching_details_for_matching, pair.id])
      end
      return configuration
    end
  end
end