module GlobalizationUtils
  def self.run_in_locale(locale, &block)
    value = nil
    exception = nil
    begin
      orig_locale = I18n.locale
      I18n.locale = locale
      value = block.call
    rescue => e
      exception = e
    ensure
      I18n.locale = orig_locale
      raise exception if exception
      return value
    end
  end

  # Globalize.with_locale doesn't update the I18n.locale. So, use Globalize.locale instead of I18n.locale
  def self.is_default_locale?(locale = Globalize.locale)
    locale == I18n.default_locale
  end
end