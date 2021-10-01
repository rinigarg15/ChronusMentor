class MatchReport::MenteeActions

  TOP_FILTERS_LIMIT = 7
  TOP_SEARCH_KEYWORDS_LIMIT = 15
  FILTERS_POPUP_LISTING_LIMIT = 10
  SEARCH_KEYWORDS_IGNORE_LIST = ["\n", ""]
  VIEWABLE_CUTOFF_DATE = "2018-09-26 00:00:00 UTC"
  attr_accessor :program, :user_ids

  def initialize(program, options)
    self.program = program
    self.user_ids = options[:mentee_view_user_ids]
  end

  def self.fetch_default_admin_view(program)
    AbstractView.find_by(default_view: AbstractView::DefaultType::MENTEES, program_id: program.id)
  end

  def get_section_data
    {filter_data: get_applied_filters_data, search_data: search_keywords_data}
  end

  def get_applied_filters_data
    UserSearchActivity.where(user_id: self.user_ids, program_id: self.program.id).includes(:profile_question).group(:profile_question).order("count_all desc").count.reject { |profile_question, _count| profile_question.nil? }
  end

  def search_keywords_data
    UserSearchActivity.get_search_keywords({program_id: self.program.id, user_id: self.user_ids}).reject{|entry| SEARCH_KEYWORDS_IGNORE_LIST.include?(entry[:keyword])}
  end

end