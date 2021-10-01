Mustache.class_eval do
  # Escape any html in the mail. If you dont want the content to be escaped pass the attributes as html_safe
  def escapeHTML(str)
    h(str)
  end
end

