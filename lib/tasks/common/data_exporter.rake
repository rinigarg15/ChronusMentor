# TASK: :export_articles
# USAGE: rake common:data_exporter:export_articles DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOT=<program_root> INCLUDE_ATTACHMENTS=<true|false>
# EXAMPLE: rake common:data_exporter:export_articles DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOT="p1" INCLUDE_ATTACHMENTS=true

# TASK: :export_article_comments
# USAGE: rake common:data_exporter:export_article_comments DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOT=<program_root>
# EXAMPLE: rake common:data_exporter:export_article_comments DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOT="p1"

# TASK: :export_forum_posts
# USAGE: rake common:data_exporter:export_forum_posts DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOT=<program_root> INCLUDE_ATTACHMENTS=<true|false>
# EXAMPLE: rake common:data_exporter:export_forum_posts DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOT="p1" INCLUDE_ATTACHMENTS=false

# TASK: :export_announcements
# USAGE: rake common:data_exporter:export_announcements DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOT=<program_root> INCLUDE_ATTACHMENTS=<true|false>
# EXAMPLE: rake common:data_exporter:export_announcements DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOT="p1" INCLUDE_ATTACHMENTS=true

namespace :common do
  namespace :data_exporter do
    desc "Exports Articles"
    task export_articles: :environment do
      Common::RakeModule::Utils.execute_task do
        program = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])[0][0]
        article_term = program.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term
        article_content_proc = Proc.new do |article|
          if article.list?
            article.list_items.collect { |list_item| "Book/Site: #{list_item.content}\nDescription: #{list_item.description}" }.join("\n---\n")
          else
            article.body
          end
        end

        columns_for_export = {
          "#{article_term} ID" => :id,
          "#{article_term} Title" => :title,
          "#{article_term} Content" => article_content_proc,
          "#{article_term} Embed Code" => :embed_code,
          "Author (Name)" => Proc.new { |article| article.author.name(name_only: true) },
          "Author (Email)" => Proc.new { |article| article.author.email },
          "Number of Views" => :view_count,
          "Number of Likes" => :helpful_count,
          "Labels (comma-separated)" => Proc.new { |article| article.label_list.join(COMMON_SEPARATOR) },
          "Number of Comments" => Proc.new { |article| article.publications.collect(&:comments).flatten.size },
          "Created on" => Proc.new { |article| article.created_at.strftime("%b %d, %Y") }
        }
        articles = program.articles.includes(publications: :comments, article_content: [:list_items, :labels])
        Common::RakeModule::DataExporter.fetch_data_and_store_in_s3(articles, columns_for_export, program, ENV["INCLUDE_ATTACHMENTS"])
      end
    end

    desc "Exports Article Comments"
    task export_article_comments: :environment do
      Common::RakeModule::Utils.execute_task do
        program = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])[0][0]
        article_term = program.term_for(CustomizedTerm::TermType::ARTICLE_TERM).term

        columns_for_export = {
          "#{article_term} ID" => Proc.new { |comment| comment.publication.article_id },
          "#{article_term} Title" => Proc.new { |comment| comment.publication.article.title },
          "Comment Content" => :body,
          "Commented by (Name)" => Proc.new { |comment| comment.user.name(name_only: true) },
          "Commented by (Email)" => Proc.new { |comment| comment.user.email },
          "Commented on" => Proc.new { |comment| comment.created_at.strftime("%b %d, %Y") }
        }
        comments = Comment.where(article_publication_id: program.article_publication_ids).includes(publication: [article: :article_content], user: :member)
        Common::RakeModule::DataExporter.fetch_data_and_store_in_s3(comments, columns_for_export, program)
      end
    end

    desc "Exports Forum Posts"
    task export_forum_posts: :environment do
      Common::RakeModule::Utils.execute_task do
        program = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])[0][0]

        columns_for_export = {
          "Post ID" => :id,
          "Forum Name" => Proc.new { |post| post.forum.name },
          "Forum Description" => Proc.new { |post| post.forum.description },
          "Forum - Available for (Roles)" => Proc.new { |post| RoleConstants.to_program_role_names(post.program, post.forum.access_role_names).join(COMMON_SEPARATOR) },
          "Forum Subscriptions Count" => Proc.new { |post| post.forum.subscriptions.size },
          "Topic" => Proc.new { |post| post.topic.title },
          "Topic Created on" => Proc.new { |post| post.topic.created_at.strftime("%b %d, %Y") },
          "Topic View Count" => Proc.new { |post| post.topic.hits },
          "Topic Subscriptions Count" => Proc.new { |post| post.topic.subscriptions.size },
          "Post Content" => :body,
          "Posted by (Name)" => Proc.new { |post| post.user.name(name_only: true) },
          "Posted by (Email)" => Proc.new { |post| post.user.email },
          "Posted on" => Proc.new { |post| post.created_at.strftime("%b %d, %Y") },
          "Is the post a reply?" => Proc.new { |post| post.ancestry.present? ? "Yes" : "No" }
        }
        posts = program.posts.includes(topic: [:subscriptions, forum: [:subscriptions, :access_roles, :role_references]], user: :member)
        Common::RakeModule::DataExporter.fetch_data_and_store_in_s3(posts, columns_for_export, program, ENV["INCLUDE_ATTACHMENTS"])
      end
    end

    desc "Exports Announcements"
    task export_announcements: :environment do
      Common::RakeModule::Utils.execute_task(locale: ENV["LOCALE"]) do
        program = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])[0][0]

        columns_for_export = {
          "Announcement ID" => :id,
          "Title" => :title,
          "Message" => :body,
          "Expiration Date" => Proc.new { |announcement| announcement.expiration_date.present? ? announcement.expiration_date.strftime("%b %d, %Y") : "" },
          "For" => Proc.new { |announcement| RoleConstants.to_program_role_names(announcement.program, announcement.recipient_role_names).join(COMMON_SEPARATOR) },
          "Posted by (Name)" => Proc.new { |announcement| announcement.admin.name(name_only: true) },
          "Posted by (E-mail)" => Proc.new { |announcement| announcement.admin.email }
        }
        announcements = program.announcements.published.includes(:translations, :recipient_roles, admin: :member)
        Common::RakeModule::DataExporter.fetch_data_and_store_in_s3(announcements, columns_for_export, program, ENV["INCLUDE_ATTACHMENTS"])
      end
    end
  end
end