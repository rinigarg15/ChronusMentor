# This migration comes from acts_as_taggable_on_engine (originally 5)
# This migration is added to circumvent issue #623 and have special characters
# work properly
class ChangeCollationForTagNames< ActiveRecord::Migration[4.2]
  def up
    if ActsAsTaggableOn::Utils.using_mysql?
      execute("ALTER TABLE tags MODIFY name varchar(#{UTF8MB4_VARCHAR_LIMIT}) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;") #Changing varchar 255 to 191 to support utf8mb4 charset
    end
  end
end
