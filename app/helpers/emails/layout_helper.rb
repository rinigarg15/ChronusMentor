module Emails::LayoutHelper
  def call_to_action(link_text, link_url, button_class = "button-large", options = {})
    content_tag(:table, width: "100%", border: "0", cellspacing: "0", cellpadding: "0", class: "mobile-button-container") do
      content_tag(:tbody) do
        content_tag(:tr) do
          content_tag(:td, align: options[:button_align]||"left", style: "padding: 35px 0px 10px 0px;", class: "padding-copy") do
            content_tag(:table, border: "0", cellspacing: "0", cellpadding: "0", class: "responsive-table") do
              content_tag(:tbody) do
                content_tag(:tr) do
                  content_tag(:td, align: "center") do
                    if options[:mail_to_action]
                      mail_to(link_url, "#{link_text} &rarr;".html_safe, subject: options[:subject], class: "mobile-button #{button_class}")
                    else
                      link_to("#{link_text} &rarr;".html_safe, link_url, target: '_blank', class: "mobile-button #{button_class}")
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def email_red_alert_text(text)
    content_tag(:div, text, style: "color: #ffffff; background-color: #b30000; padding: 5px 0; text-align:center; width:70px;")
  end

  def email_alert_text(text)
    content_tag(:div, text, style: "color: #ffffff; background-color: #007272; padding: 5px 0; text-align:center; width:70px;")
  end

  def email_gray_alert_text(text)
    content_tag(:div, text, style: "color: #ffffff; background-color: #808080; padding: 5px 0; text-align:center; width:70px;")
  end
end