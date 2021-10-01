class MyFormBuilder < ActionView::Helpers::FormBuilder

  helpers = %w{text_field password_field text_area select file_field }

  helpers.each do |name|
    define_method(name) do |field_name, *args|
      options = args.extract_options!
      options[:class] ||= ''
      options[:class] << " #{name} #{"form-control" if name != "file_field"}"
      options[:title] ||= object.class.human_attribute_name(field_name) unless options[:skip_title]

      field_id = "#{object_name}_#{field_name}"

      # Convert field ids of nested resources like user[professional_profile]_about_me
      # to user_professional_profile_about_me by replacing [ and ] with _
      #
      field_id.gsub!(/[\[\]]/, '_')
      field_id.gsub!(/_+/, '_')

      title_text = options[:title]
      title_text << " *" if options.delete(:required)

      title = ""
      title += label(field_id, title_text.html_safe, :for => field_id, :class => 'control-label') unless options[:skip_title]

      help_text = if options[:help_text]
        @template.content_tag(:p, options[:help_text].html_safe, :class => "help-block")
      elsif options[:inline_help_text]
        @template.content_tag(:span, options[:inline_help_text].html_safe, :class => "help-block")
      else
        "".html_safe
      end

      super_input = (name == "select") ? super(field_name, args[0], args[1] ||{}, options) : super(field_name, options)
      input = super_input + help_text
      input = @template.content_tag(:div, input, :class => 'controls') unless options[:wrapper].to_s == 'none'

      wrapper_class = "clearfix control-group "
      wrapper_class << options[:wrapper].to_s if options[:wrapper].present?

      input = (title + input).html_safe
      input = @template.content_tag(:div, input, :class => wrapper_class)  unless options[:wrapper].to_s == 'none'
      input
    end
  end

  def controls(options = {}, &block)
    additional_class = options.delete(:class)
    @template.content_tag(:div, @template.capture(&block), {:class => "#{additional_class} controls"}.merge(options))
  end

  def control_group(options = {}, &block)
    additional_class = options.delete(:class)
    @template.content_tag(:div, @template.capture(&block), {:class => "#{additional_class} control-group"}.merge(options))
  end

  def offset(&block)
    @template.content_tag(:div, @template.capture(&block), :class => 'controls has-below')
  end

  def submit(label, *args)
    options = args.first || {}
    data_disable_with = { disable_with: 'display_string.Please_Wait'.translate }
    options[:data] = data_disable_with.merge(options[:data] || {})
    options[:class] = (options[:class] || '') + ' btn btn-primary'

    super(label, options)
  end

  def cancel_path(label, *args)
    path = args[0]
    options = args.extract_options! || {}
    data_disable_with = { disable_with: 'display_string.Please_Wait'.translate }
    options[:data] = data_disable_with.merge(options[:data] || {})
    options[:class] = (options[:class] || '') + ' btn btn-white'
    options.delete(:js_method) ? @template.link_to_function(label, path, options) : @template.link_to(label, path, options)
  end

  def actions(options = {}, &block)
    action_code = @template.capture(&block)

    required_text = "".html_safe
    # Required fields information.
    if options[:fields_required]
      required_text = (options[:fields_required] == :all) ? "common_text.help_text.all_fields_required".translate : "common_text.help_text.fields_required".translate
      required_text = @template.content_tag(:div, required_text, :class => "fields_required has-below-1")
    end
    @template.content_tag(:div, (required_text + action_code).html_safe, :class => 'form-actions')
  end

end
