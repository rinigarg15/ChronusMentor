module ArticlesHelper
  def excerpt(article)
    case article.type
    when ArticleContent::Type::LIST
      art_link = link_to("display_string.see_more_raquo_html".translate, article_path(article))
      all_items = article.list_items.compact
      items = all_items[0..3]
      text = "".html_safe
      items.each do |x|
        text += content_tag(:li, banner_of(x, :mini => true) + (x == items.last && all_items.size > 4 ? ("&nbsp;"+ art_link): "").html_safe)
      end
      content_tag(:ul, text.html_safe, :class => 'list_excerpt m-b-0')
    when ArticleContent::Type::MEDIA
      display_embed_content(article)
    when ArticleContent::Type::UPLOAD_ARTICLE
      truncate_extra(article.body, false)
    when ArticleContent::Type::TEXT,
         nil
      truncate_extra(article.body)
    end
  end

  def truncate_extra(content, html_safe = true)
    content = content.html_safe if html_safe
    truncate_html(chronus_sanitize_while_render(auto_link(content), :sanitization_version => @current_organization.security_setting.sanitization_version), :max_length => 200)
  end

  def type_of(article)
    {
      ArticleContent::Type::TEXT => "feature.article.content.types.general_label".translate,
      ArticleContent::Type::LIST => "feature.article.content.types.list_label".translate,
      ArticleContent::Type::MEDIA => "feature.article.content.types.media_label".translate,
      ArticleContent::Type::UPLOAD_ARTICLE => "feature.article.content.types.upload_label".translate(Article: _Article)
    }[article.type]
  end

  def comment_html_id(comment)
    "comment_#{comment.id}"
  end

  #
  # Displays a the logo for the given article type.
  # Supports icons for doc, docx, xls, xlxx, ppt, pptx, pdf, rar, zip [Other types - png, jpg etc shows a paperclip)
  #
  def display_type_logo(article)
    icon_class = case article.article_content.attachment.content_type.to_s
    when "application/pdf"
      "fa-file-pdf-o"
    when "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "fa-file-word-o"
    when "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "fa-file-excel-o"
    when "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "fa-file-powerpoint-o"
    when "application/rar", "application/x-rar", "application/x-rar-compressed"
      "fa-archive-o"
    when "application/zip", "application/x-zip", "application/x-zip-compressed"
      "fa-archive-o"
    else
      "fa-file"
    end
    get_icon_content("fa #{icon_class}")
  end

  # Differentiate between new and existing records
  def fields_for_listitem(item, &block)
    prefix = item.new_record? ? 'new' : 'existing'
    simple_fields_for("article[article_content][#{prefix}_listitem_attributes][]", item, &block)
  end

  # Render the autocompleter for a new/existing book list item
  def autocompleter_for_item(item)
    if item.new_record?
      object_id = "article_article_content_new_listitem_attributes_#{item.id}_content"
      object_name = "article[article_content][new_listitem_attributes][#{item.id}][content]"
    else
      object_id = "article_article_content_existing_listitem_attributes_#{item.id}_content"
      object_name = "article[article_content][existing_listitem_attributes][#{item.id}][content]"
    end

    return control_group do
      content_tag(:label, set_required_field_label(item.label_for_content), class: "control-label", for: object_id) +
      controls do
        text_field_tag(object_name, item.content || "", class: "form-control", id: object_id)
      end
    end
  end

  def thumbnail_of(item)
    case item
    when BookListItem
      book_image(item)
    when SiteListItem
      site_preview_image(item)
    end
  end

  def banner_of(item, options = {})
    case item
    when BookListItem
      options[:mini] ? mini_book_banner(item) : book_banner(item)
    when SiteListItem
      options[:mini] ? mini_site_banner(item) : site_banner(item)
    end
  end

  # --- Impl ---
  def site_preview_image list_item
    script = <<-END
      <script type="text/javascript">stw_pagepix('#{list_item.content}', '1390f7b3796fd1b', 'vsm', 0);</script>
    END
    script
  end

  def book_image(item)
    book_image = item.presenter.image_link || 'book-icon.gif'
    link_to(image_tag(book_image, :class => 'amazon_img media-object center-block img-thumbnail', size: "100x100"), book_link(item), :target => "_blank")
  end

  # If the book has an amazon link, return it or else craft a google books query url and return it
  def book_link(item)
    item.presenter.try(:amazon_link) || "http://books.google.com/books?q=#{item.content}"
  end

  def mini_book_banner(item)
    link_to(item.content, book_link(item), :target => "_blank")
  end

  def book_banner(item)
    rating_and_author = "".html_safe
    author = item.presenter.author
    rating_and_author << "<span class='author text-muted'>#{"feature.article.content.by_author_html".translate(author: content_tag(:b, author))}</span>".html_safe if author

    content_tag(:h4, class: "book_details media-heading text-xs-center text-sm-left") do
      concat mini_book_banner(item)
      concat content_tag(:div, :class => 'info p-t-xxs small') { rating_and_author } unless rating_and_author.blank?
    end
  end

  def mini_site_banner(item)
    link_to(item.content, item.content, :target => "_blank")
  end

  def site_banner(item)
    content_tag(:h4, class: "sitelink media-heading text-xs-center text-sm-left") do
      mini_site_banner(item)
    end
  end

  def article_label_links(article)
    article_content = article.article_content
    labels = []
    article_content.labels.each do |label|
      labels << {
        content: link_to(label.name, articles_path(label: label.name), class: "text-default"),
        label_class: "label-default"
      }
    end
    labels_container(labels)
  end

  #
  # Renders the label filters using the vertical filters pattern.
  #
  # === Params
  # * <tt>active_label</tt> : selected <code>Label</code>
  # * <tt>all_labels</tt>   : Array of all <code>Label</code>s
  # * <tt>total_count</tt>  : Count of articles with all labels.
  #
  def listing_label_links(active_label, all_labels, total_count)
    items = []
    active_label_text = active_label ? active_label.name : "common_text.search.all_results".translate(results: "feature.article.content.labels".translate)

    items <<  {
      :text => "common_text.search.all_results".translate(results: "feature.article.content.labels".translate),
      :count => total_count,
      :url => url_for(params.to_unsafe_h.merge(:label => nil))
    }

    all_labels.each do |label_name, count|
      items <<  {
        :text => label_name,
        :count => count,
        :url => articles_path(label: label_name)
      }
    end

    content_tag(:div, id: "article_labels") do
      vertical_filters(active_label_text, items)
    end
  end

  def tag_field_with_auto_complete(form_object, tag_names, article_term)
    (form_object.input :label_list, :as =>  :string, :input_html => {:class => "tag_list_input col-xs-12 no-padding", :input_tags => tag_names, :title => "feature.article.header.labels".translate(article: article_term), value: form_object.object.label_list.to_s},
      :label =>  "feature.article.header.labels".translate(article: article_term)) +
      content_tag("span", "feature.article.content.tag_helptext".translate, :class => "help-block")
  end

  def edit_or_create_page_title(article)
    blank_titles = {
      ArticleContent::Type::TEXT => "feature.article.content.types.general_new_title".translate(Article: _Article),
      ArticleContent::Type::LIST => "feature.article.content.types.list_new_title".translate,
      ArticleContent::Type::MEDIA => "feature.article.content.types.media_new_title".translate(Article: _Article),
      ArticleContent::Type::UPLOAD_ARTICLE => "feature.article.content.types.upload_new_title".translate(Article: _Article)
    }

    if article.new_record?
      blank_titles[article.type.to_s]
    elsif article.real_status == ArticleContent::Status::PUBLISHED
      article.list? ? "feature.article.action.edit_list".translate : "feature.article.action.edit_article".translate(Article: _Article)
    elsif article.real_status == ArticleContent::Status::DRAFT
      # Not published even once, but not a new record.
      title = (article.title.empty? ? "feature.article.content.no_title".translate : article.title)
      "#{title} " + "feature.article.header.draft_label".translate
    end
  end

  def get_common_article_actions(article, comments_count, options = {})
    left_actions = []
    btn_class = "btn btn-sm noshadow m-b-xs"

    # Like
    marked_helpful = article.rated_by_user?(wob_member)
    like_contents = get_toggle_contents_for_like_following_button(article.helpful_count, marked_helpful, label_key: "feature.question_answers.content.n_like", label_icon: "fa fa-thumbs-up")
    left_actions << toggle_button(rate_article_path(article, format: :js), like_contents, marked_helpful, class: "rating_link #{btn_class}", handle_html_data_attr: true, toggle_class: { active: "btn-primary", inactive: "btn-white" } )

    # Comments
    unless options[:no_comments_info]
      comment_action = options[:listing] ? article_path(article, scroll_to: "comments_box") : "javascript:void(0)"
      left_actions << link_to(append_text_to_icon("fa fa-comments", get_comment_action_label(comments_count)), comment_action, class: "cjs_comment_action_button #{btn_class} btn-white", data: { comment_form_suffix: "#{article.id}" } )
    end

    # Views
    view_content = get_safe_string
    view_content += content_tag(:span, article.view_count, class: "m-r-xs")
    view_content += content_tag(:span, "feature.article.content.views_stat".translate(count: article.view_count), class: "hidden-xs")
    left_actions << content_tag(:span, append_text_to_icon("fa fa-eye", view_content), class: "#{btn_class} btn-white cursor-default no-waves")

    # Flagging
    unless options[:listing]
      right_action = popup_link_to_flag_content(article, link_class: "#{btn_class} btn-white pull-right", label_name_class: "hidden-xs")
    end

    if left_actions.present? || right_action.present?
      content_tag(:div, class: "clearfix m-t-md") do
        if left_actions.present?
          concat(content_tag(:div, class: "btn-group btn-group-sm pull-left") do
            content = get_safe_string
            left_actions.each do |action|
              content += action
            end
            content
          end)
        end
        concat right_action if right_action.present?
      end
    end
  end

  def get_article_actions_for_author_or_admin(article)
    return if !(wob_member.authored?(article) || current_user.can_manage_articles?)

    actions = []
    actions << {
      label: append_text_to_icon("fa fa-pencil", "feature.article.action.edit_article".translate(Article: _Article)),
      url: edit_article_path(article),
      btn_class_name: "ct_edit_article"
    }
    actions << {
      label: append_text_to_icon("fa fa-trash", "feature.article.action.delete_article".translate(Article: _Article)),
      url: article_path(article),
      method: :delete,
      data: { confirm: "feature.article.content.delete_warning".translate(article: _article) }
    }
    actions
  end

  def get_comment_actions(comment)
    actions = []
    flag_content_action = popup_link_to_flag_content(comment, get_hash: true)
    actions << flag_content_action if flag_content_action.present?
    if comment.user == current_user || current_user.can_manage_articles?
      actions << {
        label: append_text_to_icon("fa fa-trash", "display_string.Delete".translate),
        url: article_comment_path(comment.publication.article, comment, format: :js),
        method: :delete,
        data: {
          confirm: "feature.article.content.delete_comment_warn".translate,
          remote: true
        }
      }
    end
    actions
  end

  def render_community_widget_article_content(article)
    content_tag(:div, class: "clearfix height-65 overflowy-ellipsis break-word-all") do
      link_to(content_tag(:h4, truncate_html(article.article_content.title, max_length: 65), class: "m-b-xs maxheight-30 overflowy-ellipsis h5 no-margins text-info"), article_path(article, src: EngagementIndex::Src::MENTORING_COMMUNITY_WIDGET), class: "btn-link") +
      content_tag(:div, class: "m-t-xs inline m-b-sm") do
        content_tag(:span, append_text_to_icon("fa fa-clock-o", "feature.resources.content.time_ago".translate(time: time_ago_in_words(article.article_content.updated_at))), class: "small text-muted")
      end
    end +
    content_tag(:div, class: "height-54 break-word-all overflowy-ellipsis p-r-xs") do
      HtmlToPlainText.plain_text(get_content_to_render_inside_community_widget(article))
    end
  end

  def get_content_to_render_inside_community_widget(article)
    if article.type == ArticleContent::Type::MEDIA
      "feature.article.content.embedded_media_content_inside".translate
    elsif [ArticleContent::Type::TEXT, ArticleContent::Type::LIST].include?(article.type)
      excerpt(article)
    end
  end

  def get_list_item_description(list_item)
    if list_item.description.blank?
      content_tag(:span, "feature.article.content.no_desc".translate(article: _article), class: "text-muted")
    else
      sanitize(auto_link(list_item.description))
    end
  end

  def display_embed_content(article)
    return unless article.media?

    content = content_tag(:div, article.embed_code.html_safe, class: "cjs_embedded_media")
    html_doc = Nokogiri::HTML(article.embed_code)
    # If embed_code contains any of <video>, <embed>, <iframe> or <object> tags, then wrap it in bootstrap's media-responsive classes.
    # Reference: http://getbootstrap.com/components/#responsive-embed
    if html_doc.xpath("//video").present? || html_doc.xpath("//embed").present? || html_doc.xpath("//iframe").present? || html_doc.xpath("//object").present?
      content = content_tag(:div, class: "embed-responsive embed-responsive-16by9") do
        content
      end
    end
    content
  end

  def display_uploaded_article_content(article)
    return unless article.uploaded_content?

    content = ""
    content += display_type_logo(article)
    content += article.article_content.attachment_file_name
    content += " ( #{link_to append_text_to_icon('fa fa-download', 'display_string.Download'.translate), article.article_content.attachment.url, :target => '_blank', :class => 'cjs_android_download_files', :data => {:filename => article.article_content.attachment_file_name, :targeturl => article.article_content.attachment.url}} )".html_safe
    content.html_safe
  end

  def get_comment_action_label(comments_count)
    content_tag(:span, class: "cjs_comments_count") do
      content = get_safe_string
      content += content_tag(:span, comments_count, class: "m-r-xs") if comments_count > 0
      content += content_tag(:span, "feature.article.content.n_comment".translate(count: comments_count), class: "hidden-xs")
      content
    end
  end

  def article_comments_container(article_publication)
    return if article_publication.blank?

    comments = article_publication.comments.includes(:flags, user: [:roles, member: :profile_picture])
    comments_container(comments,
      comment_partial: "comments/comment",
      comment_partial_key: :comment,
      new_comment_partial: "comments/new_comment_form",
      new_comment_partial_locals: { article: article_publication.article },
      container_id: "comments_box"
    )
  end
end