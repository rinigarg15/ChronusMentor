# Using 'translate' instead of 'I18n#translate' for the following reasons:
# 1. Thrown MissingTranslation messages will be turned into inline spans
# 2. Scope the key by the current partial if the key starts with a period
# 3. MAIN : It’ll mark the translation as safe HTML if the key has the suffix “_html” or the last element of the key is the word “html”

class MissingHtmlSafeSuffixException < StandardError
  attr_accessor :key, :value

  def initialize(key, value)
    @key = key
    @value = value
  end

  def message
    "Value for '#{key}' contains unsafe html content"
  end
  alias :to_s :message
end

class ChronusTranslationHelper
  extend ActionView::Helpers::TranslationHelper

  def self.needs_html_suffix?(key, val)
    return false if key.match(/_html$/).present?
    return !h(val).match(/\&lt\;|\&gt\;|\&amp\;nbsp\;|\&amp\;quot\;|\&amp\;raquo\;|\&amp\;laquo\;/).nil?
  end

  # Handlers: [:log, :airbrake_notify, :raise]
  def self.notify_html_suffix_needed(key, val)
    exception = MissingHtmlSafeSuffixException.new(key, val)
    handlers = Hash[MISSING_HTML_SUFFIX_HANDLERS.collect{|h| [h, true]}]
    respond_to?(:logger) ? logger.info(exception.message) : puts(exception.message) if handlers[:log]
    Airbrake.notify(exception) if handlers[:airbrake_notify]
    raise exception if handlers[:raise]
  end
end

String.class_eval do
  # Checks if the translated text is empty (happens when the keyvalue is set to
  # empty string) and handles the case as it handles a missing translation
  def translate(options = {})
    tranlsated_text = ChronusTranslationHelper.translate(self, options.merge(raise: false))
    ChronusTranslationHelper.notify_html_suffix_needed(self, tranlsated_text) if APP_CONFIG[:check_missing_html_suffix] && ChronusTranslationHelper.needs_html_suffix?(self, tranlsated_text)
    return tranlsated_text if !tranlsated_text.empty? || I18n.locale == :en
    I18n.custom_exception_handler(I18n::MissingTranslation.new(I18n.locale, self, options), I18n.locale, self, options)
  end

end

DateTime.instance_eval do
  def localize(object, options = {})
    if object.nil?
      return nil
    end
    raise ArgumentError, "Object must be a Date, DateTime or Time object. #{object.inspect} given." unless object.respond_to?(:strftime)
    format = options.delete(:format) || :default
    begin
      I18n.localize(object, :format => format)
    rescue => error
      raise error if I18n.locale == I18n.default_locale
      return error.message
    end
  end
end

module I18n
  def self.custom_exception_handler(exception, locale, key, options)
    if MissingTranslation === exception && locale != :en
      handle_missing_translation(:en, key, options)
    elsif MissingInterpolationArgument === exception && locale != :en
      Airbrake.notify(exception)
      handle_missing_translation(:en, key, options)
    else
      I18n::ExceptionHandler.new.send(:call, exception, locale, key, options)
    end
  end

  def self.handle_missing_translation(locale, key, options)
    result = catch(:exception) do
      backend.translate(locale, key, options)
    end

    result.is_a?(I18n::MissingTranslation) ? I18n::ExceptionHandler.new.send(:call, result, locale, key, options) : result
  end

  #In test env it raises exception
  def self.raise_translation_missing_exception(*args)
    raise "i18n #{args.first}"
  end

  def self.missing_translation_silent_notifier(*args)
    exception = args[0]
    locale = args[1]
    key = args[2]
    options = args[3]
    Airbrake.notify(Exception.new(exception)) if MissingTranslation === exception && locale == I18n.default_locale
    I18n::ExceptionHandler.new.send(:call, exception, locale, key, options)
  end
end