# https://github.com/plataformatec/simple_form/issues/694
# This file can be removed on updating simple_form gem. We will get exception in mailer template edit page without this file.

module SimpleForm

  module Inputs
    class CollectionInput < Base
      def input_options
        options = super()

        if @collection.present? && options[:as] == :radio_buttons
          options[:input_wrapper_html] ||= {}
          options[:input_wrapper_html][:class] ||= ""
          options[:input_wrapper_html][:class] += " choices_wrapper"
          options[:input_wrapper_html][:role] = "group"
          options[:input_wrapper_html]["aria-label"] = options[:label].presence || label_text
        end
        options
      end
    end
  end

  module ActionViewExtensions
    module Builder
      def collection_radio_buttons(attribute, collection, value_method, text_method, options={}, html_options={})
        rendered_collection = render_collection(
          collection, value_method, text_method, options, html_options
        ) do |item, value, text, default_html_options|
          builder = instantiate_collection_builder(RadioButtonBuilder, attribute, item, value, text, default_html_options)

          if block_given?
            yield builder
          else
            builder.radio_button + builder.label(:class => "collection_radio_buttons")
          end
        end

        wrap_rendered_collection(rendered_collection, options)
      end

      def collection_check_boxes(attribute, collection, value_method, text_method, options={}, html_options={})
        rendered_collection = render_collection(
          collection, value_method, text_method, options, html_options
        ) do |item, value, text, default_html_options|
          default_html_options[:multiple] = true
          builder = instantiate_collection_builder(CheckBoxBuilder, attribute, item, value, text, default_html_options)

          if block_given?
            yield builder
          else
            builder.check_box + builder.label(:class => "collection_check_boxes")
          end
        end

        # Append a hidden field to make sure something will be sent back to the
        # server if all checkboxes are unchecked.
        hidden = @template.hidden_field_tag("#{object_name}[#{attribute}][]", "", :id => nil)

        wrap_rendered_collection(rendered_collection + hidden, options)
      end

      private

      def instantiate_collection_builder(builder_class, attribute, item, value, text, html_options)
        builder_class.new(self, attribute, item, sanitize_attribute_name(attribute, value), text, value, html_options)
      end
    end
  end

  # Use the column_for_attribute method instead of type_for_attribute method for translated attributes
  # since the latter returned string for text data types and they were rendered as text boxes instead of textarea
  class FormBuilder
    def find_attribute_column(attribute_name)
      if @object.respond_to?(:type_for_attribute) && @object.has_attribute?(attribute_name) && @object.class.respond_to?(:translated_attribute_names) && !attribute_name.in?(@object.class.translated_attribute_names)
        @object.type_for_attribute(attribute_name.to_s)
      elsif @object.respond_to?(:column_for_attribute) && @object.has_attribute?(attribute_name)
        @object.column_for_attribute(attribute_name)
      end
    end
  end
end
