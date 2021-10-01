module TabConfigurationHelper
  module MentoringCommunityTabConfigurationHelper
    def configure_mentoring_community_tab
      cname = params[:controller]
      aname = params[:action]

      mentoring_community_subtabs = init_sub_tabs

      if current_user.accessible_program_forums.any? && @current_program.forums_enabled?
        mentoring_community_subtabs = set_forum_sub_tabs(mentoring_community_subtabs, cname, aname)
      end

      mentoring_community_subtabs = filter_allowed_mentoring_community_tabs(mentoring_community_subtabs, cname, aname)
      if @current_program.program_events_enabled?
        mentoring_community_subtabs = set_program_events_sub_tabs(mentoring_community_subtabs, cname, aname)
      end
      add_mentoring_community_tab(mentoring_community_subtabs)
    end

    private

    def filter_allowed_mentoring_community_tabs(mentoring_community_subtabs, cname, aname)
      if add_qa_sub_tabs?
        mentoring_community_subtabs = set_qa_sub_tabs(mentoring_community_subtabs, cname, aname)
      elsif add_articles_sub_tabs?
        mentoring_community_subtabs = set_articles_sub_tabs(mentoring_community_subtabs, cname, aname)
      elsif add_advice_sub_tabs?
        mentoring_community_subtabs = set_advice_sub_tabs(mentoring_community_subtabs, cname, aname)
      end
      return mentoring_community_subtabs
    end

    def add_qa_sub_tabs?
      show_qa_tab? && !show_articles_tab?
    end

    def add_articles_sub_tabs?
      show_articles_tab? && !show_qa_tab?
    end

    def add_advice_sub_tabs?
      show_qa_tab? && show_articles_tab?
    end

    def add_mentoring_community_tab(mentoring_community_subtabs)
      if mentoring_community_subtabs[TabConfiguration::Tab::SubTabKeys::LINKS_LIST].size > 0
        add_tab(
          "tab_constants.community".translate, '#', false,
          subtabs: mentoring_community_subtabs, open_by_default: true, tab_class: "cjs_mentoring_community_header"
        )
      end
    end

    def show_qa_tab?
      @current_program.qa_enabled? && current_user.can_view_questions?
    end

    def show_articles_tab?
      @current_program.articles_enabled? && current_user.can_view_articles?
    end

    def set_forum_sub_tabs(mentoring_community_subtabs, cname, aname)
      options = {
        is_active_hash: (["topics"].include?(cname) || (cname == "posts" && aname != "moderatable_posts") || (cname == "forums" && aname == "show")),
        has_partial_hash: true,
        render_path_hash: "forums/forum_subtabs"
      }
      set_sub_tab_values(mentoring_community_subtabs, TabConfiguration::Tab::SubTabLinks::FORUM, options)
    end

    def set_qa_sub_tabs(mentoring_community_subtabs, cname, _aname)
      options = {
        is_active_hash: (cname == "qa_questions" || cname == "qa_answers"),
        link_label_hash: TabConstants::QA,
        has_partial_hash: false,
        render_path_hash: qa_questions_path(src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::MENTORING_COMMUNITY),
        icon_class_hash: "fa-file-text"
      }
      set_sub_tab_values(mentoring_community_subtabs, TabConfiguration::Tab::SubTabLinks::QA, options)
    end

    def set_articles_sub_tabs(mentoring_community_subtabs, cname, _aname)
      options = {
        is_active_hash: (cname == "articles"),
        link_label_hash: _Articles,
        has_partial_hash: false,
        render_path_hash: articles_path(sub_src: EngagementIndex::SideBarSubSrc::MENTORING_COMMUNITY, src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION),
        icon_class_hash: "fa-feed"
      }
      set_sub_tab_values(mentoring_community_subtabs, TabConfiguration::Tab::SubTabLinks::ARTICLES, options)
    end

    def set_advice_sub_tabs(mentoring_community_subtabs, cname, _aname)
      options = {
        is_active_hash: (cname == "articles" || cname == "qa_questions" || cname == "qa_answers"),
        has_partial_hash: true,
        render_path_hash: "articles/article_qa_question_subtabs"
      }
      set_sub_tab_values(mentoring_community_subtabs, TabConfiguration::Tab::SubTabLinks::ADVICE, options)
    end

    def set_program_events_sub_tabs(mentoring_community_subtabs, cname, aname)
      options = {
        is_active_hash: (cname == 'program_events' && aname == 'index'),
        link_label_hash: "quick_links.program.program_events_v1".translate,
        has_partial_hash: false,
        render_path_hash: program_events_path(src: EngagementIndex::Src::BrowseMentors::SIDE_NAVIGATION, sub_src: EngagementIndex::SideBarSubSrc::MENTORING_COMMUNITY),
        icon_class_hash: "fa-calendar-o",
        badge_count_hash: current_user.get_unanswered_program_events.size
      }
      set_sub_tab_values(mentoring_community_subtabs, TabConfiguration::Tab::SubTabLinks::PROGRAM_EVENTS, options)
    end
  end
end