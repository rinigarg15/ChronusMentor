namespace :clone do
  # USAGE: rake clone:articles DOMAIN="localhost.com" SUBDOMAIN="test" SOURCE_PROGRAM_ROOT="p1" TARGET_PROGRAM_ROOTS="p2,p3"
  desc "Clone articles between programs"
  task articles: :environment do
    Common::RakeModule::Utils.execute_task do
      source_program_root = ENV["SOURCE_PROGRAM_ROOT"]
      target_programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["TARGET_PROGRAM_ROOTS"])
      source_program = organization.programs.find_by(root: source_program_root)
      raise "Invalid Program Root #{source_program_root}" if source_program.blank?

      target_programs.each do |target_program|
        source_program.articles.includes(:publications, article_content: :taggings).each { |article| make_a_clone(article, target_program) }
      end
    end
    ElasticsearchReindexing.indexing_flipping_deleting([Article.name])
  end

  private

  def make_a_clone(article, target_program)
    unless article.author.user_in_program(target_program).present?
      Common::RakeModule::Utils.print_error_messages("Can't copy #{article.title}. Error: Author is not part of #{target_program.root}")
      return
    end
    new_article, new_content = get_new_article_and_content(article, target_program)
    old_content = article.article_content
    article_type = old_content.type
    if article_type == ArticleContent::Type::LIST
      clone_article_list_items(old_content, new_content)
    elsif article_type == ArticleContent::Type::UPLOAD_ARTICLE
      new_content.attachment = ARTICLE_STORAGE_OPTIONS[:storage] == :s3 ? AttachmentUtils.get_remote_data(old_content.attachment.url) : old_content.attachment
    end
    new_content.save!
    new_article.save!
    Common::RakeModule::Utils.print_success_messages("Copied #{new_content.title} to #{target_program.root}")
  end

  def get_new_article_and_content(article, target_program)
    article_content = article.article_content
    new_article_content = clone_record(article_content, attrs: { published_at: Time.now })
    new_article = nil
    ArticleObserver.without_callback(:after_create) do
      Article::PublicationObserver.without_callback(:after_create) do
        new_article = clone_record(article, attrs: { article_content: new_article_content, view_count: 0, helpful_count: 0 })
        new_article.publications.build(program_id: target_program.id)
      end
    end
    clone_article_labels(article_content, new_article_content) if article_content.taggings.present?
    [new_article, new_article_content]
  end

  def clone_article_list_items(old_content, new_content)
    old_content.list_items.each do |item|
      new_content.list_items.build(item.dup.attributes.except("article_content_id"))
    end
  end

  def clone_article_labels(old_content, new_content)
    old_content.taggings.each do |tag|
      new_content.taggings.build(tag.dup.attributes.except("taggable_id"))
    end
  end

  def clone_record(record, options = {})
    new_record = record.dup
    assign_attrs(new_record, options[:attrs]) if options[:attrs].present?
    new_record
  end

  def assign_attrs(record, attrs)
    attrs.each { |attr, value| record.send("#{attr}=", value) }
  end
end