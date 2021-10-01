module PrototypeHelper
  def link_to_remote(name, options = {}, html_options = nil)
    data_options = {}
    [:confirm, :before, :complete, :success].each do |key|
      data_options.merge!(key => options.delete(key)) if options[key].present?
    end

    last_argument = {}
    last_argument.merge!({remote: true})
    if options[:html].present?
      last_argument.merge!(options.delete(:html))
    elsif html_options.present?
      last_argument.merge!(html_options)
    end
    last_argument.merge!(data: data_options) if data_options.keys.present?
    last_argument.merge!({method: options.delete(:method)}) if options[:method].present?

    args = []
    args << name
    args << options.delete(:url)
    args << last_argument
    link_to(*args)
  end

  def link_to_function(name, click_method, html_options = nil)
    args = []
    args << name
    args << "javascript:void(0)"
    last_argument = {}
    last_argument.deep_merge!(html_options) if html_options.present?
    last_argument.deep_merge!({data: {click: click_method}})
    args << last_argument
    link_to(*args)
  end

  def button_to_function(name, click_method, html_options = nil)
    tag(:input, (html_options || {}).merge(:type => 'button', :value => name, data: {click: click_method}))
  end
end

ActionController::Base.helper PrototypeHelper
