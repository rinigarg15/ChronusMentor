class AddYearMonthDayToPublications< ActiveRecord::Migration[4.2]
  def up
    add_column :publications, :day, :integer
    add_column :publications, :month, :integer
    add_column :publications, :year, :integer

    ActiveRecord::Base.transaction do
      Publication.where("date is not null").find_each do |pub|
        date = pub[:date]
        pub.day = date.day
        pub.month = date.month
        pub.year = date.year
        pub.save!
      end
    end
    remove_column :publications, :date
  end
  
  def down
    add_column :publications, :date, :date

    ActiveRecord::Base.transaction do
      Publication.where("year is not null AND month is not null AND day is not null").find_each do |pub|
        pub.date = Date.civil(pub.year, pub.month, pub.day)
        pub.save!
      end
    end
    remove_column :publications, :day
    remove_column :publications, :month
    remove_column :publications, :year
  end
end
