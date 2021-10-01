module ActionMailerMessageDeliverWithLocale
  # @mail_locale is set in chronus_mailer.
  def deliver_now
    mail_locale = self.instance_variable_get("@mail_locale")
    if mail_locale.present?
      ChronusMailer.run_with_locale(mail_locale) do
        super
      end
    else
      super
    end
  end
end


ActionMailer::MessageDelivery.prepend(ActionMailerMessageDeliverWithLocale)