module FormErrorHelper
  # Helper to display for errors.
  def error_messages_for(*params)
    options = params.extract_options!.symbolize_keys

    if object = options.delete(:object)
      objects = Array.wrap(object)
    else
      objects = params.collect {|object_name| instance_variable_get("@#{object_name}") }.compact
    end

    count  = objects.inject(0) {|sum, object| sum + object.errors.count }
    unless count.zero?
      html = {}
      [:id, :class].each do |key|
        if options.include?(key)
          value = options[key]
          html[key] = value unless value.blank?
        else
          html[key] = 'alert alert-danger'
        end
      end
      options[:object_name] ||= params.first

      header_message = options[:header_message] || 'common_text.error_msg.please_correct_highlighted_errors'.translate
      message = options[:message]
      error_messages = objects.sum {|object| object.errors.full_messages.map {|msg| content_tag(:li, ERB::Util.html_escape(msg)) } }.join.html_safe

      contents = ''.html_safe
      contents << content_tag(options[:header_tag] || :h3 , header_message) unless header_message.blank?
      contents << content_tag(:p, message) unless message.blank?
      contents << content_tag(:ul, error_messages)

      content_tag(:div, contents, html)
    else
      ''
    end
  end

  
end