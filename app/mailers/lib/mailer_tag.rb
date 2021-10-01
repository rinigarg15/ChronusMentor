class MailerTag
  def self.register_tags(name, &block)
    [ChronusActionMailer::Base, WidgetTag].each do |klass|
        klass.register_tags(name) do
          block.call(klass)
        end
    end
  end
end
