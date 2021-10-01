class UpdateInvalidLinksInDefaultAboutPage< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      links_to_update = [
        ["www.linkedin.com/company/chronus-corporation", "www.linkedin.com/company/chronussoftware"],
        ["www.youtube.com/user/ChronusCorp", "www.youtube.com/c/Chronus"],
        ["twitter.com/Chronus_Inc", "twitter.com/ChronusSoftware"],
        ["www.facebook.com/pages/Chronus-Corporation/250982824916923", "www.facebook.com/ChronusSoftware"],
        ['<li class="slideshare"><a href="http://www.slideshare.net/ChronusCorporation" target="_blank">Slideshare</a></li>', ''],
        ['<li class="slideshare"><a href="https://www.slideshare.net/ChronusCorporation" target="_blank">Slideshare</a></li>', '']
      ]

      links_to_update.each do |link_to_update|
        old_url, new_url = link_to_update
        Page.where("content like '%#{old_url}%'").find_each do |page|
          next if page.content.blank?
          page.update_column(:content, page.content.gsub(old_url, new_url))
        end

        Page::Translation.where("content like '%#{old_url}%'").find_each do |page_translation|
          next if page_translation.content.blank?
          page_translation.update_column(:content, page_translation.content.gsub(old_url, new_url))
        end
      end
    end
  end

  def down
  end
end
