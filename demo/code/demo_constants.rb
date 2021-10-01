# encoding: utf-8
module Demo
  module ProgramType
    CORPORATE = 0
    STUDENT = 1
  end
  module Names
    FemaleNames = %w( Mary Patricia Linda Barbara Elizabeth Jennifer Maria Susan Margaret Dorothy Lisa Nancy Karen Betty Helen Sandra Donna Carol Ruth Sharon Michelle Laura Sarah Kimberly Deborah Jessica Shirley Cynthia Angela Melissa Brenda Amy Anna Rebecca Virginia Kathleen Pamela Martha Debra Amanda Stephanie Carolyn Christine Marie Janet Catherine Frances Ann Joyce Diane Alice Julie Heather Teresa Doris Gloria Evelyn Jean Cheryl Mildred Katherine Joan Ashley Judith Rose Janice Kelly Nicole Judy Christina Kathy Theresa Beverly Denise Tammy Irene Jane Lori Rachel Marilyn Andrea Kathryn Louise Sara Anne Jacqueline Wanda Bonnie Julia Ruby Lois Tina Phyllis Norma Paula Diana Annie Lillian Emily Robin )
    MaleNames = %w( James John Robert Michael William David Richard Charles Joseph Thomas Chistopher Daniel Paul Mark Donald George Kenneth Steven Edward Brian Ronald Anthony Kevin Jason Matthew Gary Timothy Jose Larry Jeffrey Frank Scott Eric Stephen Andrew Raymond Gregory Joshua Jerry Dennis Walter Patrick Peter Harold Douglas Henry Carl Arthur Ryan Roger Joe Juan Jack Albert Jonathan Justin Terry Gerald Keith Samuel Willie Ralph Lawrence Nicholas Roy Benjamin Bruce Brandon Adam Harry Fred Wayne Billy Steve Louis Jeremy Aaron Randy Howard Eugene Carlos Russell Bobby Victor Martin Ernest Phillip Todd Jesse Craig Alan Shawn Clarence Sean Philip Chris Johnny Earl Jimmy Antonio )
  end
  module Locations
    Addresses = [
      #U.S.Cities
      {:city => "New York", :state => "New York", :country => "United States"},
      {:city => "Buffalo", :state => "New York", :country => "United States"},
      {:city => "Yonkers", :state => "New York", :country => "United States"},
      {:city => "Rochester", :state => "New York", :country => "United States"},
      {:city => "San Francisco", :state => "California", :country => "United States"},
      {:city => "Los Angeles", :state => "California", :country => "United States"},
      {:city => "San Diego", :state => "California", :country => "United States"},
      {:city => "San Jose", :state => "California", :country => "United States"},
      {:city => "Long Beach", :state => "California", :country => "United States"},
      {:city => "Santa Ana", :state => "California", :country => "United States"},
      {:city => "Riverside", :state => "California", :country => "United States"},
      {:city => "Chicago", :state => "Illinois", :country => "United States"},
      {:city => "Houston", :state => "Texas", :country => "United States"},
      {:city => "San Antonio", :state => "Texas", :country => "United States"},
      {:city => "Plano", :state => "Texas", :country => "United States"},
      {:city => "Brownsville", :state => "Texas", :country => "United States"},
      {:city => "Austin", :state => "Texas", :country => "United States"},
      {:city => "El Paso", :state => "Texas", :country => "United States"},
      {:city => "Dallas", :state => "Texas", :country => "United States"},
      {:city => "Jacksonville", :state => "Florida", :country => "United States"},
      {:city => "Tampa", :state => "Florida", :country => "United States"},
      {:city => "Tallahassee", :state => "Florida", :country => "United States"},
      {:city => "Orlando", :state => "Florida", :country => "United States"},
      {:city => "Hollywood", :state => "Florida", :country => "United States"},
      {:city => "Gainesville", :state => "Florida", :country => "United States"},
      {:city => "Miami Gardens", :state => "Florida", :country => "United States"},
      {:city => "Palm Bay", :state => "Florida", :country => "United States"},
      {:city => "Aurora", :state => "Colorado", :country => "United States"},
      {:city => "Denver", :state => "Colorado", :country => "United States"},
      {:city => "Aurora", :state => "Colorado", :country => "United States"},
      {:city => "Lakewood", :state => "Colorado", :country => "United States"},
      {:city => "Arvada", :state => "Colorado", :country => "United States"},
      {:city => "Pueblo", :state => "Colorado", :country => "United States"},
      {:city => "Fort Collins", :state => "Colorado", :country => "United States"},
      {:city => "Memphis", :state => "Tennessee", :country => "United States"},
      {:city => "Knoxville", :state => "Tennessee", :country => "United States"},
      {:city => "Nashville", :state => "Tennessee", :country => "United States"},
      {:city => "Clarksville", :state => "Tennessee", :country => "United States"},
      {:city => "Murfreesboro", :state => "Tennessee", :country => "United States"},
      {:city => "Worcester", :state => "Massachusetts", :country => "United States"},
      {:city => "Boston", :state => "Massachusetts", :country => "United States"},
      {:city => "Lowell", :state => "Massachusetts", :country => "United States"},
      {:city => "Cambridge", :state => "Massachusetts", :country => "United States"},
      {:city => "Springfield", :state => "Massachusetts", :country => "United States"},
      #Other Cities
      {:city => "Florence", :state => "Florence", :country => "Italy"},
      {:city => "Paris", :state => "Ile-de-France", :country => "France"},
      {:city => "Rome", :state => "Province of Rome", :country => "Italy"},
      {:city => "Earley", :state => "Berkshire", :country => "United Kingdom"},
      {:city => "Newbury", :state => "Berkshire", :country => "United Kingdom"},
      {:city => "Woodley", :state => "Berkshire", :country => "United Kingdom"},
      {:city => "Thatcham", :state => "Berkshire", :country => "United Kingdom"},
      {:city => "Reading", :state => "Berkshire", :country => "United Kingdom"},
      {:city => "Eton", :state => "Berkshire", :country => "United Kingdom"},
      {:city => "St Mary Cary", :state => "Greater London", :country => "United Kingdom"},
      {:city => "Barnet", :state => "Greater London", :country => "United Kingdom"},
      {:city => "Bexley", :state => "Greater London", :country => "United Kingdom"},
      {:city => "West Ham", :state => "Greater London", :country => "United Kingdom"},
      {:city => "Tottenham", :state => "Greater London", :country => "United Kingdom"},
      {:city => "Sydney", :state => "New South Wales", :country => "Australia"},
      {:city => "Melbourne", :state => "Victoria", :country => "Australia"},
      {:city => "Brisbane", :state => "Queensland", :country => "Australia"},
      {:city => "Cairns", :state => "Queensland", :country => "Australia"},
    ]
  end
  module Educations
    MenteeDegrees =["BTech", "BE", "DIISc", "DSc", "FIISc", "MSc", "MSc(Engg)", "MDes", "MIISc"]
    MentorDegrees = ["MS", "MTech", "MBA", "ME", "ME(Int)", "PG Diploma", "PhD"]
    Majors  = [
      "Computer Engineering",
      "Computer Science",
      "Electrical Engineering",
      "Business Information Technology",
      "Business Information Systems",
      "Industrial and Systems Engineering",
      "Information Systems",
      "Management Information Systems",
      "Operations Management"
       ]

    Schools = [
      "Massachusetts Institute of Technology",
      "Stanford University",
      "University of California--Berkeley",
      "Georgia Institute of Technology",
      "California Institute of Technology",
      "University of Illinois--Urbana-Champaign",
      "Carnegie Mellon University",
      "University of Michigan--Ann Arbor",
      "University of Texas--Austin (Cockrell)",
      "Cornell University",
      "Virginia Tech"
    ]
  end

  module Workex
    MenteeJobTitles = [
      "Associate Engineer",
      "System Analyst",
      "Senior Engineer",
      "Program Manager",
      "Project Manager",
      "Business Analyst",
      "Software Engineer"
    ]

    MentorJobTitles = [
      "CEO",
      "CFO",
      "COO",
      "Senior Vice President",
      "Vice President",
      "Director",
      "Associate Director",
      "General Manager"
    ]

    Organizations = ["Microsoft Corporation",
      "Qualcomm Inc.",
      "Nokia",
      "Adobe Systems",
      "GE",
      "Intel Corporation",
      "PepsiCo",
      "Citibank",
      "Cisco Systems",
      "Google Inc."
    ]
  end

  module QA
    # Format:
    #    {
    #      :summary => <question-text>,
    #      :description => <question-description>,
    #      :answer_file => <answer-file-name>
    #    },
    StudentQuestions = [
      {
        :summary => "As a mentee, what do I gain from the mentor program?",
        :description => "I want to know how this program will benefit me in my professional development.",
        :answer_file => "student_1.txt"
      },
      {
        :summary => "What are my responsibilities as a mentee?",
        :description => "Need to know what I need to do, what rules to follow to get the most of this.",
        :answer_file => "student_2.txt"
      },
      {
        :summary => "Typo in My Thank You Note sent to my boss",
        :description => "I whipped-off quick Thank You email to my boss after a successful sales meeting.  All of a sudden, I realized that I had spelled the company name WRONGLY in the email.  What should I do?",
        :answer_file => "student_3.txt"
      }
    ]

    MentorQuestions = [
      {
        :summary => "As a mentor, What should I do when I first meet my mentee and what should we talk about?",
        :description => "Need tips from other mentors to have a very productive first meeting with mentee.",
        :answer_file => "mentor_1.txt"
      },
      {
        :summary => "As as a mentor, how can I help mentees?",
        :description => "It would be nice if somone enumerate the types of help I can offer as a mentor",
        :answer_file => "mentor_2.txt"
      },
      {
        :summary => "How should I keep in touch with my mentee?",
        :description => "Please suggest how one can have a effective offline interation with mentees. Do I need to be part of socialnetworks like facebook, orkut etc.?",
        :answer_file => "mentor_3.txt"
      }
    ]
  end

  module Articles
    CommonArticles = [
      #Text Articles
      { :title => "History of Mentoring", :content => "history_of_mentoring.txt", :type => ArticleContent::Type::TEXT, :label_list => "Mentoring" },
      { :title => "Mentorship experiences", :content => "mentoring_experiences.txt", :type => ArticleContent::Type::TEXT, :label_list => "Mentoring" },
      { :title => "General tips for communicating with your Mentees!", :content => "tips_for_communication.txt", :type => ArticleContent::Type::TEXT, :label_list => "Communication" },
      { :title => "First Conversation", :content => "first_conversation.txt", :type => ArticleContent::Type::TEXT, :label_list => "Communication" },
      { :title => "How to get the most out of your relationship", :content => "general_tips.txt", :type => ArticleContent::Type::TEXT,:label_list => "Mentoring" },
      #Media Articles
      { :title => "Randy Pausch Lecture: Time Management", :content => 'randy_paush.txt', :type => ArticleContent::Type::MEDIA, :label_list => "Time Management" },
      #List Articles
      { :title => "Time Management", :type => ArticleContent::Type::LIST, :list => [
          [:book, "Time Management from Inside Out", " "],
          [:book, "Organizing Your Day: Time Management Techniques That will Work for You", " "]
          ], :label_list => "Time Management"
      },
      { :title => "Time Management Books", :type => ArticleContent::Type::LIST, :list => [
          [:book, "The Time Trap: The Classic Book on Time Management", " "],
          [:book, "The 25 Best Time Management Tools and Techniques: How to Get More Done Without Driving Yourself Crazy", " "]
          ], :label_list => "Time Management"
      }

    ]
    module Student
      TextArticles = [
      { :title => "10 Insights for discovering your dream job", :content => "dream_job.txt", :type => ArticleContent::Type::TEXT, :label_list => "career" },
      { :title => "Re-Envisioning Mentorship in the Age of the Millennial", :content => "Millennial.txt", :type => ArticleContent::Type::TEXT,:label_list => "Mentoring" }
      ]

      MediaArticles = [
      { :title => "Resources for Entrepreneurship", :content => "entre.txt", :type => ArticleContent::Type::MEDIA,:label_list => "Entrepreneurship" },
      { :title => "Career Advice: Job Interview", :content => "interview.txt", :type => ArticleContent::Type::MEDIA }

      ]

      ListArticles = [
      { :title => "Some of my favorite Books", :type => ArticleContent::Type::LIST, :list => [
          [:book, "Cracking the Coding Interview: 150 Programming Questions and Solutions", "For techies"],
          [:book, "How to Get Into the Top Consulting Firms: A Surefire Case Interview Method", " "],
          [:book, "Sweaty Palms: The Neglected Art of Being Interviewed", "Really funny"],
          [:book, "Ask the Headhunter: Reinventing the Interview to Win the Job", "One of my favorites"]
          ], :label_list => "books"
      }
      ]
    end

    module Enterprise
      TextArticles = [
      { :title => "Dont unpack that suitcase", :content => "unpack.txt", :type => ArticleContent::Type::TEXT }
      ]

      MediaArticles = [
      { :title => "Mind Map: Mapping Your Career Path - IQmatrix.com", :content => "mindmap.txt", :type => ArticleContent::Type::MEDIA,:label_list => "career path" }
      ]

      ListArticles = [
      { :title => "Resources On Mentoring", :type => ArticleContent::Type::LIST, :list => [
          [:book, "The Power Of Mentoring: Shaping People Who Will Shape The World", "This book has a lot of good tips on how to mentor others. The thing that is great about this book from other books on mentoring is that it really takes time to develop you as a mentor or mentoree in your character. Martin Sanders doesn't just tell you how to mentor but gives good reflective questions throughout this book to help you develop yourself."],
          [:book, "The Heart of Mentoring: Ten Proven Principles for Developing People to Their Fullest Potential", "This book helped me over-come all this by getting to the root of mentoring, that it isn't a matter of skill initially. Rather, it starts with the proper perspective of mentoring, and being mentored or as the title conveys, it starts with heart. This book has helped me, more than any other mentoring book, to be effective in all my mentoring relationships at home, at work, and in the community. I highly recommend it!"],
          [:site, "http://managementhelp.org/guiding/mentrng/mentrng.htm", "A very good resource on mentoring. Starting right from definition, it contains essays on various topics like being a mentor, getting a mentor, setting up a program etc."]
        ], :label_list => "Mentoring"
      }
      ]

    end
    ArticleComments = [
      "The article is very helpful. Thanks",
      "Informative and useful.",
      "Yes, I agree with you on this.",
      "Very valid points.Enjoyed reading the article",
      "Where can I find more information on this topic?",
      "Well said..."
    ]
  end

  module Survey
    AnswersTakeaway = [
      "I have improved my leadership skills.",
      "My efficiency and time management skills have been enhanced",
      "Public speaking - confidence and inpiration from my mentor",
      "I have learnt a great deal about the management and am committed to the company.",
      "Networking with senior management staff.",
      "I now have a clear vision of my career goals."
    ]
    AnswersBlocks = [
      "Mentor does not seem to have time for me",
      "My mentor is not punctual",
      "I need help on how to get the most",
      "I was not able to spend time for the program"
    ]
    AnswersPartnership = [
      "I am learning a lot from my mentor and the other resources on the mentor site",
      "Everything is going great",
      "My mentor takes genuine interest in my growth",
      "Thanks for the program",
      "The articles published by mentors and answers are great!"
    ]
  end

  module MentorRequests
    Requests = [
      "As a career switcher from finance to marketing, I would like to learn more about the mentor's career path in marketing. The mentor's background with various marketing experiences would be great to talk about.",
      "I am looking for advice on a career change to Finance.",
      "I'm looking to find a mentor who can help give me advice and direction as I transition from academics to the industry. I'm interested in somebody who has had experience across industries (e.g not just high-tech).",
      "I want learn more about what makes a successful financial advisor & investor.",
      "I want to know how to enter new industry because I am right now looking for a refreshing switch."
    ]

    FavoriteReasons = [
      "The mentor and I share the same interests",
      "The mentor is in the industry I like to get into",
      "The have the known the mentor personally and we can connect better",
      "I know the mentor personally",
      "The mentor has a strong technology, marketing and sales background",
      "Interests and working backgrounds seem similar!",
      "The mentor is a great and inspiring speaker",
      "The mentor's background aligns with my projected career path",
      "Mentor's bright, creative mind, something I lack",
      "Strong academic background, as well as interesting professional background",
      "The mentor's consulting and management experience is impressive",
      "I have Enterprenerial background and want to explore that path with the guidance of the mentor",
      "I'd like to understand how the mentor made the switch from Techinal domain to Sales & Marketing.",
      "Mentor's track record in the international arena",
      "The mentor has done the same major as i've taken now, would be more familiar with the subject."
    ]
  end

  module Announcements
    All = [
      { :title => "Welcome Mentors and Mentees!", :file => "all.txt" }
    ]

    Mentors = [
      { :title => "Invitation to Mentor Lunch and Networking event", :file => "mentors.txt" }
    ]

    Students = [
      { :title => "Mark your calendar. Mentee Lunch and Networking event is coming up", :file => "mentees.txt" }
    ]
  end

  module Groups
    module Scraps
      Students = [
        "How do I succeed in life?",
        "Can we meet in person so that we can talk more about what help I'm in need of?",
        "Thank you. That was helpful.",
        "Do you think one can ever be truly objective when dealing with their own problems?",
        "I need to improve on my time management skills",
        "I need help with concentration on studies.",
        "I am in my second year of college and looking to do an MBA in a good college. I would like to what things I should be planning on.",
        "What are the absolute, unbreakable rules of resume writing? And what about the 'breakable' ones?",
        "Do I need more than one version of my resume?",
        "What resources are available to me to find an internship or job?"
      ]

      Mentors = [
        "The correct advice to give is the advice that is desired.",
        "A pint of example is worth a gallon of advice.",
        "When all else fails, read the instructions.",
        "Give me ambiguity or give me something else.",
        "Jumping to conclusions can be bad exercise.",
        "If you don't care where you're going any road will get you there.",
        "If the going gets easy you may be going downhill.",
        "The easy way is always mined.",
        "Don't put all your eggs in the wrong basket.",
        "He who forgives ends the quarrel.",
        "Always bear in mind that your own resolution to succeed is more important than any one thing.",
        "A great secret of success is to go through life as a man who never gets used up.",
        "To follow, without halt, one aim: There's the secret of success.",
        "It is possible to fail in many ways...while to succeed is possible only in one way.",
        "Of course there is no formula for success except perhaps an unconditional acceptance of life and what it brings.",
        "I don't know the key to success, but the key to failure is trying to please everybody.",
        "The person who makes a success of living is the one who see his goal steadily and aims for it unswervingly. That is dedication.",
        "Please call me tomorrow evening, so that we can discuss about this in detail",
        "I have added a few new tasks. Let us work towards those milestones",
        "I'm in the Seattle downtown area during the day. I could meet you around 5 or 5:30 on Tuesday."
      ]
    end

    Tasks = [
      "Review the resume and suggest improvements",
      "Discuss career goals",
      "Identify weaknesses and find ways of addressing them",
      "Create a plan",
      "Eliminate distractions",
      "Read the book 'Getting Things Done'",
      "Meeting next Tuesday 6:30PM",
      "Get in touch with Ms. Amanda",
      "Attend the seminar on Risk-taking",
      "Compose the Speech and get it reviewed",
      "Identify competitors",
      "Do SWOT analysis of self"
    ]
    module Meetings
      Locations = [
        "Cafeteria" ,
        "Room No:12",
        "Conference hall",
        "Office Lobby",
        "Skype"
        ]
     Descriptions = [
        "Let us discuss about the goals of mentoring",
        "Clarification of a doubt in career plans",
        "Talk about performance",
        "Tips on improving speed and efficiency",
        "General talk"
      ]
     Topics = [
        "Goals of mentoring",
        "Clarification of a doubt",
        "Performance Review",
        "Tips",
        "Introduction"
      ]
    end
  end

  module Forums
    module Student
      MentorTopics = [
      { :title => "Great Success!", :body => "What attributes to greater success?", :posts => "stu_mentor_1.txt" },
      { :title => "Rejecting Requests", :body => "Is it bad to reject a mentee's request?", :posts => "stu_mentor_2.txt" },
      { :title => "Mentee Communication", :body => "How to effectively communicate with mentee?", :posts => "stu_mentor_3.txt" },
      { :title => "Loss of motivation", :body => "How to overcome the loss of motivation?", :posts => "stu_mentor_4.txt" },
      { :title => "Request for testimonial", :body => "Please add testimonials", :posts => "stu_mentor_5.txt" }
    ]

      MenteeTopics = [
       { :title => "Job Fair prep", :body => "Job Fair is happening next week. Provide with tips to do better.", :posts => "stu_mentee_1.txt" },
       { :title => "Unresponsive mentor", :body => "How to deal with an unresponsive mentor?", :posts => "stu_mentee_2.txt" },
       { :title => "Career Steps Seminar", :body => "Please share the notes of Career Steps Seminar", :posts => "stu_mentee_3.txt" },
       { :title => "Connecting in Facebook", :body => "Should I be Facebook friends with my mentor?", :posts => "stu_mentee_4.txt" },
       { :title => "Mentee Check-In and Lunch", :body => "Mentee Check-In and Lunch", :posts => "stu_mentee_5.txt" },
      ]
    end
    module Enterprise
    #same as Student for now, since content is not ready.
    end
  end

  module Reasons
    module Education
      MenteeReasons = [
        "I want to get help regarding my higher studies",
        "Placement traning help needed",
        "I want to get mentored on entrepreneurship",
        "I want to network with alumnis"
      ]
      MentorReasons = [
        "I want to mentor my students on their future plans",
        "Encouraging more students to take up research",
        "Identifying students who need counselling on higher studies",
        "Helping out my juniors to explore different career options"
      ]
    end
    module Enterprise
      MenteeReasons = [
        "I want to get help regarding my project options in the company",
        "Getting to know the higher management better",
        "Help needed in terms of rising in my career ladder",
        "I want to switch from testing to development team. Good advice from senior developers needed."
      ]
      MentorReasons = [
        "Helping employees to visualise their career growth in the company.",
        "Encouraging more junior employees to take up corporate responsibility",
        "Identifying high talent among the employees and motivating them.",
        "To mentor new hires to easily adapt to the work culture"
      ]
    end
  end

  module Profession
    Titles = [
      "Associate Developer",
      "Programmer",
      "Test Engineer",
      "Senior Program Manager",
      "Program Analyst",
      "Marketing manager",
      "Financial consultant"
    ]
  end
end

