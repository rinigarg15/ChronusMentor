class UpdateBrowserWarningForWcag < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      contents_to_update = [
        ["<img src=\"/browser_warning/chrome.png\">", "<img src=\"/browser_warning/chrome.png\" alt=\"Google Chrome\">"],
        ["<img src=\"/browser_warning/firefox.png\">", "<img src=\"/browser_warning/firefox.png\" alt=\"Firefox\">"],
        ["<img src=\"/browser_warning/ie.png\">", "<img src=\"/browser_warning/ie.png\" alt=\"Internet Explorer\">"],
        ["<img src=\"/browser_warning/safari.png\">", "<img src=\"/browser_warning/safari.png\" alt=\"Safari\">"]
      ]

      klasses_to_update = [Organization::Translation]
      klasses_to_update.each do |klass|
        time_now = Time.now
        klass.all.each do |object|
          browser_warning = object.browser_warning
          next if browser_warning.blank?

          contents_to_update.each { |old_content, new_content| browser_warning.gsub!(old_content, new_content) }
          object.update_column(:browser_warning, browser_warning)
        end
      end
    end
  end

  def down
  end
end