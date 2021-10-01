module ElasticsearchConstants
  PARALLEL_PROCESSING_BATCH_SIZE = 1000
  DEFAULT_REFRESH_INTERVAL = '1s'
  INDEX_INCLUDES_HASH = {
    "GroupStateChange" => [:group],
    "Group" => [:state_changes, {:mentors => [:member]}, {:students => [:member]}, {:created_by => [:member]}, {:closed_by => [:member]}, :membership_settings, :memberships, :mentoring_model_tasks, :mentoring_model_milestones, :mentoring_model, :scraps, :posts, :survey_answers],
    "UserStateChange" => [:user],
    "User" => [:state_transitions, :connection_membership_state_changes, :taggings, :user_stat, :first_activity, :sent_mentor_offers, :received_mentor_requests, roles: [:translations], member: [{location_answer: [:location]}, {profile_answers: [:answer_choices, profile_question: {question_choices: :translations}]}, {member_language: [:language]}, :profile_picture], connection_memberships: [group: [:student_memberships]], recommendation_preferences: [:mentor_recommendation], program: [role_questions: {profile_question: [:conditional_question_choices]}]],
    "Meeting" => [:attendees],
    "MentorRequest" => [student: [:member], mentor: [:member]],
    "ProjectRequest" => [:group, sender: [:member]],
    "ThreeSixty::SurveyAssessee" => [:survey],
    "QaQuestion" => [user: [:member], qa_answers: [user: [:member]], program: [:roles]],
    "Member" => [location_answer: [:location], users: [:role_references, :groups], member_language: [:language]],
    "Article" => [:author, :publications, :article_content => [:labels]],
    "Resource" => [:resource_publications],
    "Topic" => [:published_posts, user: [:member]]
  }

  AUTOCOMPLETE_SETTINGS = {
    "analysis": {
      "filter": {
        "autocomplete_filter": {
          "type": "edge_ngram",
          "min_gram": 1,
          "max_gram": 20
        }
      },
      "tokenizer": {
        "punctuation": {
          "type": "pattern",
          "pattern": "[ ,!?]"
        }
      },
      "analyzer": {
        "autocomplete_index_analyzer": {
          "type":      "custom",
          "tokenizer": "punctuation",
          "filter": [
            "lowercase",
            "autocomplete_filter",
            "asciifolding"]
        },
        "autocomplete_search_analyzer": {
          "type":      "custom",
          "tokenizer": "punctuation",
          "filter": ["lowercase", "asciifolding"]
        }
      }
    }
  }

  ACCENT_SETTINGS = {
    "analysis": {
      "analyzer": {
        "accent_analyzer": {
          "tokenizer": "standard",
          "filter": ["lowercase", "asciifolding"]
        }
      }
    }
  }

  URL_ANALYZER_SETTINGS = {
    # Urls present should be searchable split by dot.
    "analysis": {
      "char_filter": {
        "full_stop_replacer": {
          "type": "pattern_replace",
          "pattern": "\\.",
          "replacement": " "
        },
        "hyphen_replacer": {
          "type": "pattern_replace",
          "pattern": "-",
          "replacement": "_"
        }
      },
      "filter": {
        "stopwords_filter": {
          "type": "stop",
          "stopwords": File.read("config/stopwords.txt").split(", ")
        }
      },
      "analyzer": {
        "url_analyzer": {
          "type":         "custom",
          "tokenizer":    "standard",
          "filter":       ["standard", "lowercase", "stopwords_filter"],
          "char_filter":  ["full_stop_replacer", "hyphen_replacer"]
        }
      }
    }
  }

  SORTABLE_ANALYZER_SETTINGS = {
    "analysis": {
      "analyzer": {
        "sortable": {
          "type":       "custom",
          "tokenizer":  "keyword",
          "filter":     ["lowercase"]
        }
      }
    }
  }

  LANGUAGE_ANALYZER_SETTINGS = {
    "analysis": {
      "filter": {
        "english_stop": {
          "type":       "stop",
          "stopwords":  File.read("config/stopwords.txt").split(", ")
        },
        "english_keywords": {
          "type":       "keyword_marker",
          "keywords":   ["example"]
        },
        "english_stemmer": {
          "type":       "stemmer",
          "language":   "english"
        },
        "english_possessive_stemmer": {
          "type":       "stemmer",
          "language":   "possessive_english"
        },
        "french_elision": {
          "type":         "elision",
          "articles_case": true,
          "articles": [
              "l", "m", "t", "qu", "n", "s",
              "j", "d", "c", "jusqu", "quoiqu",
              "lorsqu", "puisqu"
            ]
        },
        "french_stop": {
          "type":       "stop",
          "stopwords":  File.read("config/stopwords.txt").split(", ")
        },
        "french_keywords": {
          "type":       "keyword_marker",
          "keywords":   ["Exemple"]
        },
        "french_stemmer": {
          "type":       "stemmer",
          "language":   "light_french"
        }
      },
      "analyzer": {
        "chronus_english_html_analyzer": {
          "tokenizer":  "standard",
          "filter": [
            "english_possessive_stemmer",
            "lowercase",
            "english_stop",
            "english_keywords",
            "english_stemmer"
            ],
          "char_filter": ["html_strip"]
        },
        "chronus_french_html_analyzer": {
          "tokenizer":  "standard",
          "filter": [
            "french_elision",
            "lowercase",
            "french_stop",
            "french_keywords",
            "french_stemmer"
            ],
          "char_filter": ["html_strip"]
        },
        "chronus_english": {
          "type": "english",
          "stopwords": File.read("config/stopwords.txt").split(", ")
        },
        "chronus_french": {
          "type": "french",
          "stopwords": File.read("config/stopwords.txt").split(", ")
        }
      }
    }
  }

  STOPWORDS_ANALYZER_SETTINGS = {
    "analysis": {
      "analyzer": {
        "stopwords": {
          "type": "standard",
          "stopwords": File.read("config/stopwords.txt").split(", ")
        }
      }
    }
  }

  GROUP_DYNAMIC_TEMPLATES = [
    {
      "role_users_strings": {
        "path_match": 'role_users_full_name.*',
        "mapping": {
          "type": 'text',
          "analyzer": 'sortable',
          "fielddata": true
        }
      }
    },
    {
      "total_slots": {
        "path_match": 'membership_setting_total_slots.*',
        "mapping": {
          "type": 'integer'
        }
      }
    },
    {
      "slots_taken": {
        "path_match": 'membership_setting_slots_taken.*',
        "mapping": {
          "type": 'integer'
        }
      }
    },
    {
      "slots_remaining": {
        "path_match": 'membership_setting_slots_remaining.*',
        "mapping": {
          "type": 'integer'
        }
      }
    },
    {
      "meetings_activity": {
        "path_match": 'meetings_activity_for_all_roles.*',
        "mapping": {
          "type": 'integer'
        }
      }
    },
    {
      "login_activity": {
        "path_match": 'get_rolewise_login_activity_for_group.*',
        "mapping": {
          "type": 'integer'
        }
      }
    },
    {
      "messages_activity": {
        "path_match": 'get_rolewise_messages_activity_for_group.*',
        "mapping": {
          "type": 'integer'
        }
      }
    },
    {
      "posts_activity": {
        "path_match": 'get_rolewise_posts_activity_for_group.*',
        "mapping": {
          "type": 'integer'
        }
      }
    }
  ]

  HTML_ANALYZER_SETTINGS = {
    "analysis": {
      "filter": {
        "stopwords_filter": {
          "type": "stop",
          "stopwords": File.read("config/stopwords.txt").split(", ")
        }
      },
      "analyzer": {
        "html_analyzer": {
          "type":         "custom",
          "tokenizer":    "standard",
          "filter":       ["standard", "lowercase", "stopwords_filter"],
          "char_filter":  ["html_strip"]
        }
      }
    }
  }

  WORD_CLOUD_ANALYZER_SETTINGS = {
    "analysis": {
      "filter": {
        "stopwords_filter": {
          "type": "stop",
          "stopwords": File.read("config/wordcloud_stopwords.txt").split(", ")
        }
      },
      "analyzer": {
        "word_cloud_analyzer": {
          "type":      "custom",
          "tokenizer": "keyword",
          "filter": [
            "lowercase", "stopwords_filter"
          ],
          "char_filter":  ["html_strip"]
        }
      }
    }
  }

  module SortOrder
    ASC = "asc"
    DESC = "desc"
  end

  module DATE_RANGE_FORMATS
    DATE_WITH_TIME_AND_ZONE = "yyyy-MM-dd HH:mm:ss ZZ"

    # Equivalent Rails way to format the time to match the elasticsearch date range format
    FORMATS_HASH = {
      DATE_WITH_TIME_AND_ZONE => "%Y-%m-%d %H:%M:%S %z"
    }
  end

end
