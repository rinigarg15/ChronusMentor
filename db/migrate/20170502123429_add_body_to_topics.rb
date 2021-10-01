class AddBodyToTopics< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Topic.table_name do |t|
        t.add_column :body, "text"
      end
    end

    ChronusMigrate.data_migration do
      Topic.reset_column_information
      puts "Migrating first post body to topic body"
      ActiveRecord::Base.transaction do
        first_post_ids = Post.select("MIN(posts.created_at) AS first_post_date, id").group(:topic_id).collect(&:id)
        posts_scope = Post.where(id: first_post_ids).includes(:topic)

        counter = 0
        posts_scope.find_each do |post|
          post.topic.update_column(:body, post.body)
          counter += 1
          print "." if (counter % 1000 == 0)
        end

        posts_with_children = Post.where(ancestry: posts_scope.pluck(:id)).pluck(:ancestry)
        DataScrubber.new.send(:scrub_posts, posts_scope.where.not(id: posts_with_children).pluck(:id))
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Topic.table_name do |t|
        t.remove_column :body
      end
    end
  end
end