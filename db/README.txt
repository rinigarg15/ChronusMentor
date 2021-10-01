== How to write DB Migrations - Guidelines:

RAILS TO MYSQL DATATYPES:
=========================

Rails Migration Symbol  |  MySQL Data Type

:binary                 |  blob
:boolean                |  tinyint(1)
:date                   |  date
:datetime               |  datetime
:decimal                |  decimal
:float                  |  float
:integer                |  int(11)
:string                 |  varchar(255)
:text                   |  text
:time                   |  time
:timestamp              |  datetime

DDL MIGRATIONS:
==============

Example 1:

class AddTestToUsers < ActiveRecord::Migration
  def up
    ChronusMigrate.ddl_migration(:has_downtime => false) do
      Lhm.change_table :users do |m|
        m.add_column :test, "varchar(255) DEFAULT 'test' NOT NULL"
        m.add_index :test
        m.change_column_default(:state, "inactive")
        m.drop_column_default(:state)
        m.rename_column :state_change_reason, :state_change_cause
        m.change_column(:badge_text, "text NOT NULL")
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration(:has_downtime => false) do
      Lhm.change_table :users do |m|
        m.change_column(:badge_text, "VARCHAR(255) NULL")
        m.rename_column :state_change_cause, :state_change_reason
        m.change_column_default(:state, "active")
        m.remove_index :test
        m.remove_column :test
      end
    end
  end
end

Example 2:

ChronusMigrate.ddl_migration(:has_downtime => false) do
  create_table :mentoring_models do |t|
    t.string :title
    t.text :description
    t.boolean :default, default: false
    t.belongs_to :program
    t.integer :mentoring_period
    t.timestamps null: false
  end
end

Example 3:

ChronusMigrate.ddl_migration(:has_downtime => false) do
  drop_table :mentoring_models
end

3 things to note:
=================

1. Enclose every DDL operation within ChronusMigrate.ddl_migration
2. Modifying a table - use Lhm.change_table
3. Create and Drop table - Don't use Lhm
4. Pass option (:has_downtime => true) in remove_column if needed. By default, (:has_downtime => false)

Methods available in Lhm for migrations:
========================================

1. add_column - Adds a new column to a table.
2. remove_column - Removes a column from a table.
3. add_index - Adds a new index to a table.
4. remove_index - Removes an index from a table.
5. rename_column - Renames an old column to a new column.
6. change_column - Changes the datatype of a column.
7. change_column_default - Changes the default value of a column.
8. drop_column_default - Drops the default value of a column(changes to NULL)
9. add_unique_index - Adds a unique index to a table.

DATA MIGRATIONS:
===============

Example 1:

ChronusMigrate.data_migration do
  ActiveRecord::Base.transaction do
    Organization.all.group_by(&:account_name).each do |account_name, organizations|
      next if organizations.size <= 1
      organizations.each do |organization|
        organization.update_attribute(:account_name, (organization.account_name.presence || "<blank>") + " - " + organization.id.to_s)
      end
    end
  end
end

Example 2:

ChronusMigrate.data_migration(:has_downtime => false) do
  ActiveRecord::Base.transaction do
    Organization.all.group_by(&:account_name).each do |account_name, organizations|
      next if organizations.size <= 1
      organizations.each do |organization|
        organization.update_attribute(:account_name, (organization.account_name.presence || "<blank>") + " - " + organization.id.to_s)
      end
    end
  end
end


Points to be noted:
===================

1. Use ChronusMigrate.ddl_migration for all DDL(Data Definition Language) operations(Lhm.change_table inside when applicable). This will not incure any downtime.(explained above on how to use)
2. Use ChronusMigrate.data_migration for all DML(Data Manipulation Language) operations. This can incur downtime. (explained above on how to use)
3. Add 'has_downtime: false' option if you're absolutely sure that migrations won't affect the end users still accessing the old codebase, (ie)it can be run without the need of maintenance page. By default, all data migrations will incur downtime unless this option is specified. (explained below on how to use)
4. Always use up and down methods. Don't use change method.
5. Always use mysql datatypes, instead of rails datatypes.(explained above on how to map from rails to mysql datatype)
6. If you have both DML and DDL migrations, write DDL migrations first.
7. To cleanup leftover tables after failed migration, use Lhm.cleanup(:run).
8. Gemfile changes will no longer cause downtime. Developer/Reviewer should have to mention to the deployer if he needs to have downtime deployment on Gemfile changes.
9. Always try to write the migrations in such a way that, it works with old code as well as new code keeping downtime in mind.
10. On how LHM works, refer - https://github.com/soundcloud/lhm

Things not to do:
=================

1. Never ever write migrations directly without enclosing within the above two functions(ChronusMigrate.ddl_migration(Lhm.change_table when applicable) and ChronusMigrate.data_migration).
2. Never ever remove column or remove index or drop table on the same day as you remove/change the code related to it.(Always schedule it for later).
3. Never use rails datatypes for LHM.
4. Never use change method to write migrations for LHM.
5. Never run db:migrate directly on any machine other than development.