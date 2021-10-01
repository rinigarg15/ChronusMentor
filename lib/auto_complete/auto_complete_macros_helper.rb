module AutoCompleteMacrosHelper

  def auto_complete_field(field_id, options = {})
    javascript_tag do
      %Q[
        jQuery(document).ready(function(){
          jQueryAutoCompleter("##{field_id}", #{options.to_json});
        });
      ].html_safe
    end
  end

  # Wrapper for text_field with added AJAX autocompletion functionality.
  #
  # In your controller, you'll need to define an action called
  # auto_complete_for to respond the AJAX calls,
  #
  def text_field_with_auto_complete(object, method, tag_options = {}, completion_options = {})
    object_id = tag_options[:id] || "#{object}_#{method}"
    completion_options[:indicator] = "cjs_autocomplete_loader_#{SecureRandom.hex(3)}"
    completion_options[:min_chars] ||= 1
    left_addon = tag_options.delete(:left_addon) || []
    right_addon = [ { type: "addon", icon_class: "fa fa-spinner fa-spin", id: completion_options[:indicator], style: "display:none;" } ]
    right_addon << tag_options.delete(:right_addon) if tag_options[:right_addon].present?
    tag_options.merge!({:autocomplete => "off"})
    construct_input_group(left_addon, right_addon, input_group_class: "col-xs-12 no-padding") do
      text_field(object, method, tag_options)
    end +
    content_tag(:div, "", :id => "#{object_id}_auto_complete", :class => "z-index-10 auto_complete col-sm-12 no-padding clearfix") +
    auto_complete_field(object_id, { :url => { :action => "auto_complete_for_#{object}_#{method}" } }.update(completion_options)).html_safe
  end

  def text_field_tag_with_auto_complete(name, value, method, tag_options = {}, completion_options = {})
    object_id = tag_options[:id]
    completion_options[:indicator] = "cjs_autocomplete_loader_#{SecureRandom.hex(3)}"
    completion_options[:min_chars] ||= 1
    left_addon = tag_options.delete(:left_addon) || []
    right_addon = [ { type: "addon", icon_class: "fa fa-spinner fa-spin", id: completion_options[:indicator], style: "display:none;" } ]
    right_addon << tag_options.delete(:right_addon) if tag_options[:right_addon].present?
    tag_options.merge!({:autocomplete => "off"})
    construct_input_group(left_addon, right_addon, input_group_class: "col-xs-12 no-padding") do
      text_field_tag(name, value, tag_options)
    end +
    content_tag(:div, "", :id => "#{object_id}_auto_complete", :class => "z-index-10 auto_complete col-sm-12 no-padding clearfix") +
    auto_complete_field(object_id, { :url => { :action => method } }.update(completion_options)).html_safe
  end
end
