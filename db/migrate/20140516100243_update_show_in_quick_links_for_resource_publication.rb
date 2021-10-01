class UpdateShowInQuickLinksForResourcePublication< ActiveRecord::Migration[4.2]
  def up
    resource_hash = Resource.includes(:translations).index_by(&:id)
    ResourcePublication.find_each do |resource_publication|
      say "Migrating resource_publication - #{resource_publication.id}"
      resource = resource_hash[resource_publication.resource_id]
      ActiveRecord::Base.transaction do
        begin
          resource_publication.show_in_quick_links = resource.show_in_quick_links
          resource_publication.save!
        rescue => exception
          say "Failed for Resource# - #{resource.id} and Resource Publication# - #{resource_publication.id}. Trace: #{exception.message}"
          raise exception
        end
      end
    end
  end

  def down
    ResourcePublication.update_all(show_in_quick_links: nil)
  end
end
