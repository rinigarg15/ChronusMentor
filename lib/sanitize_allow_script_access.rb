module SanitizeAllowScriptAccess

  #Sets AllowScripts Value as 'never' when a media article is created
  def sanitize_allowscriptaccess_in_media(content, type = :remove)
    has_allow_script_access = false
    if content.present?
      doc = Nokogiri::HTML.fragment(content)
      nodesets = doc.xpath(".//embed")
      nodesets.each do |ns|
        if ns.attribute('allowscriptaccess')
          has_allow_script_access = true
          ns.attribute('allowscriptaccess').value = 'never'
        end
      end
      nodesets = doc.xpath('.//param')
      nodesets.each do |ns|
        if ns.attribute('name').value.casecmp('allowscriptaccess') == 0 # case insensitive comparision of allowscriptaccess
          has_allow_script_access = true
          ns.attribute('value').value = 'never'
        end
      end
      content = doc.to_html
    end

    if type == :has
      has_allow_script_access
    else
      content
    end
  end

end
