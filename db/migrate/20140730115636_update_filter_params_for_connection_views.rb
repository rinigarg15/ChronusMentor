class UpdateFilterParamsForConnectionViews< ActiveRecord::Migration[4.2]
  def up
    AbstractView.where(default_view: [AbstractView::DefaultType::CONNECTIONS_NEVER_GOT_GOING, AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS, AbstractView::DefaultType::INACTIVE_CONNECTIONS]).find_each do |view|
      hsh = view.filter_params_hash
      if hsh[:sphinx_filter_hash][:per_page] || hsh[:sphinx_filter_hash][:page]
        hsh[:sphinx_filter_hash] = hsh[:sphinx_filter_hash].except(:per_page, :page)
        view.filter_params = AbstractView.convert_to_yaml(hsh)
        view.save!
      end
    end
  end

  def down
    # no down migration
  end
end
