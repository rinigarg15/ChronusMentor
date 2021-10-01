module AdminMessagesHelper

  def render_system_generated_filter(is_checked = false)
    checkbox_class = "cjs_admin_messages_system_generated"
    content_tag(:label, class: "checkbox m-t-0 m-b-0 pull-right") do
      check_box_tag(:include_system_generated, true, is_checked, class: checkbox_class, id: "include_system_generated_checkbox") +
      content_tag(:div) do
        get_safe_string + "feature.messaging.content.filter_system_generated_messages".translate + " " +
        embed_icon("fa fa-info-circle cjs-tool-tip", "", data: {desc: "feature.messaging.content.filter_example_tooltip".translate})
      end
    end +
    handle_check_box_click(".#{checkbox_class}")
  end

  def get_comment_wrapper_options(reply, from_discussion = false, from_inbox = false)
    options = {}

    if from_discussion
      options[:hidden_fields] = {}
      options[:onclick] = "jQuery('#new_post').hide();"
      options[:id] = "post_attachment"
      options[:name] = "post[attachment]"
      options[:wrapper_id] = "new_post"
      options[:attribute] = :body
      options[:input_id] = "message_content_post"
      options[:placeholder] = "feature.connection.content.placeholder.type_your_reply".translate
    else
      common_id = reply.try(:parent_id).present? ? reply.parent_id : SecureRandom.hex(3)
      options[:reply_path] = get_reply_path(reply, from_inbox)
      options[:hidden_fields] = {:parent_id => {id: "parent_id_#{common_id}"}, :ref_obj_id => {id: "ref_obj_id_#{common_id}"}}
      options[:onclick] = "jQuery('#new_admin_message_#{reply.parent_id}').hide();"
      options[:id] = "#{reply.class.to_s.underscore}_attachment_#{reply.parent_id}"
      options[:name] = "#{reply.class.to_s.underscore}[attachment]"
      options[:wrapper_id] = "new_admin_message_#{reply.parent_id}"
      options[:attribute] = :content
      options[:input_id] = "message_content_#{reply.parent_id}"
      options[:placeholder] = "feature.messaging.placeholder.type_your_message".translate
    end
    return options
  end

  private

  def handle_check_box_click(checkbox_selector)
    javascript_tag do
      %Q[
        jQuery(document).ready(function(){
          Messages.submitSystemGeneratedBox("#{checkbox_selector}");
        });
      ].html_safe
    end
  end
end