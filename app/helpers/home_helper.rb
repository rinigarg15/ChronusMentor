module HomeHelper
  def csreport_td(options)
    change_1 = options[:change_t1]
    color_1 = change_1 > 0 ? 'green' : 'red' if change_1 != 0
    per_change_1 = options[:percent_change_t1]

    change_2 = options[:change_t2]
    color_2 = change_2 > 0 ? 'green' : 'red' if change_2 != 0
    per_change_2 = options[:percent_change_t2]

    cur_value = options[:total]

    content_tag(:td) do
      content = cur_value.to_i.to_s
      content += content_tag(:span, " / #{options[:percent_reached]}%") if options[:percent_reached]
      content += content_tag(:div, :class => "small dim", :style => 'border-top: 1px dashed #DDD') do
        per_change_1 ? content_tag(:span, "#{'+' if change_1 >= 0 }#{per_change_1.to_s}%", :style => "color: #{color_1}") : "NA"
      end
      content += content_tag(:div, :class => "small dim", :style => 'border-top: 1px dashed #DDD') do
        per_change_2 ? content_tag(:span, "#{'+' if change_2 >= 0 }#{per_change_2.to_s}%", :style => "color: #{color_2}") : "NA"
      end
      content.html_safe
    end
  end
end