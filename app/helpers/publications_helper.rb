module PublicationsHelper
  # Differentiate between new and existing records
  def fields_for_publication(question, publication, &block)
    if publication.new_record?
      fields_for("profile_answers[#{question.id}][new_publication_attributes][]", publication, &block)
    else
      fields_for("profile_answers[#{question.id}][existing_publication_attributes][]", publication, &block)
    end
  end

  # A link with value 'name' will be created which will give a new form for publication
  def add_publication_link(question, name, options = {})
    new_publication_content = render(:partial => 'publications/new_publication', :object => Publication.new, :locals => {:question => question, :required => options[:required]})
    link_to_function(name, "jQuery('#publication_cur_list_#{question.id}').append(\"#{j(new_publication_content)}\");jQuery('.cjs_add_show').show();jQuery('.cjs_question_#{question.id} .cjs_empty_message').hide();", :class => "add_icon #{options[:link_class]}")
  end

  def formatted_publication_in_listing(publication, is_listing = false, options = {})
    content_tag(:div, :class => "m-b-xs") do
      str = get_icon_content("fa fa-book")
      url_or_title = publication.url.present? ? link_to(publication.title, publication.url, :target => "_blank") : publication.title
      str << (options[:highlight] ? fetch_highlighted_answers(url_or_title, options[:common_values]) : content_tag(:strong, url_or_title))
      str << tag(:br) if options[:highlight]
      authors = content_tag(:div, content_tag(:strong, "feature.education_and_experience.content.authors".translate, :class => 'm-r-xs text-muted') + publication.authors, :class => 'm-b-xs') if publication.authors.present?
      publisher = content_tag(:span, publication.publisher) if publication.publisher.present?
      date = content_tag(:span, publication.formatted_date, :class => 'text-muted') if publication.formatted_date.present?
      desc = content_tag(:div, render_more_less(h(publication.description), 120)) if publication.description.present?
      str << content_tag(:div) do
        [publisher, date].reject(&:blank?).join(content_tag(:span, ' | ', :class => 'text-muted')).html_safe
      end
      str << authors
      str << desc
      str
    end
  end
end
