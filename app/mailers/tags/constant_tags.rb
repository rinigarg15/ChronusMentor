MailerTag.register_tags(:constant_tags) do |t|
  t.tag :connection_inactivity_notice_period, :description => Proc.new{|program| 'feature.email.tags.connection_inactivity_notice_period.description_v1'.translate(program.return_custom_term_hash)}, :eval_tag => true do
    Connection::Membership::INACTIVITY_NOTICE_PERIOD / 1.day
  end
end
