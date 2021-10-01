class UpdateDigestV2EnabledStatus< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      # digest_v2.rb: DigestV2.mailer_attributes[:uid], aggregated_mail.rb: 'nkscehaf', mentoring_area_digest.rb: 'ql9gxlz3', weekly_updates.rb: 'ca95bx5m'
      Mailer::Template.where(uid: [DigestV2.mailer_attributes[:uid], 'nkscehaf', 'ql9gxlz3', 'ca95bx5m']).group_by(&:program_id).each do |program_id, mailer_templates|
        aggregated_mail_template = mailer_templates.find { |mailer| mailer.uid == 'nkscehaf' }
        mentoring_area_digest_template = mailer_templates.find { |mailer| mailer.uid == 'ql9gxlz3' }
        weekly_updates_template = mailer_templates.find { |mailer| mailer.uid == 'ca95bx5m' }
        enable_digest_v2_template = [aggregated_mail_template, mentoring_area_digest_template, weekly_updates_template].compact.map(&:enabled).inject(:&)
        if enable_digest_v2_template == false
          digest_v2_template = mailer_templates.find { |mailer| mailer.uid == DigestV2.mailer_attributes[:uid] }
          digest_v2_template = Mailer::Template.new(program_id: program_id, uid: DigestV2.mailer_attributes[:uid]) if digest_v2_template.nil?
          digest_v2_template.enabled = false
          digest_v2_template.save
        end
        if enable_digest_v2_template == true
          digest_v2_template = mailer_templates.find { |mailer| mailer.uid == DigestV2.mailer_attributes[:uid] }
          if digest_v2_template && digest_v2_template.enabled == false
            digest_v2_template.enabled = true
            digest_v2_template.save
          end
        end
      end
    end
  end

  def down
    # nothing
  end
end
