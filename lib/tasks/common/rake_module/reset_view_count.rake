#USAGE: rake common:reset_views_flags_and_ratings DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list> RESET_ARTICLES='true' RESET_RESOURCES='true'
# EXAMPLES:
# rake common:reset_views_flags_and_ratings DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1" RESET_ARTICLES="true"

namespace :common do
  desc "Reset view count for articles and resources"
  task reset_views_flags_and_ratings: :environment do
    # View counts are stored at resource/article level and not publication level
    program_ids = Common::RakeModule::Utils.fetch_programs_and_organization(ENV['DOMAIN'], ENV['SUBDOMAIN'], ENV['ROOTS'])[0].map(&:id)
    if ENV['RESET_ARTICLES']
      article_ids = Article.joins(:publications).where(article_publications: { program_id: program_ids }).pluck(:id)
      Article.where(id: article_ids).update_all(view_count: 0, helpful_count: 0)
      Rating.where(rateable_type: Article, rateable_id: article_ids).delete_all
      Flag.where( content_type: Article, content_id: article_ids).delete_all
      Common::RakeModule::Utils.print_success_messages("View counts, ratings and flags of articles have been reset")
    end
    if ENV['RESET_RESOURCES']
      resource_ids = Resource.joins(:resource_publications).where(resource_publications: { program_id: program_ids }).pluck(:id)
      Resource.where(id: resource_ids).update_all(view_count: 0)
      Rating.where(rateable_type: Resource, rateable_id: resource_ids).delete_all
      Common::RakeModule::Utils.print_success_messages("View counts and ratings of resources have been reset")
    end
  end
end