#Overridden Lhm gem for column rename, changing column default.

#We add a Delayed Custom migration, where we record statements to be run not before indexing is done. We run these statements once the indexing is done, just before updating the new code during deployment.

#Column rename - 
# 1. We add a new column same as original column with the new column name
# 2. Then, we add triggers to copy data into new column if changed in original column
# 3. Till the indexing is finished, the triggers will be copying data into the new column from the old column
# 4. We will remove the triggers and the old column once the indexing is finished.
#Change column default -
# 1. Dont change the default value during db migration ie. before the indexing is done.
# 2. Record the change column statement and execute it at the end after indexing.



module LhmMigrationWithTruncation
# Lhm adds a prefix of 29 characters to the table name.
# This exceeds the MySQL table name limit of 64 characters. Thus overriding the prefix.
  def archive_name
    super[0...64]
  end
end

module LhmAtomicSwitcherWithTriggerRenameColumn
  #Adding extra triggers only for column rename
  def statements
    if @migration.renames.empty?
      super
    else
      super | statements_for_column_rename
    end
  end
end

module Lhm

  #Overridden this to not call invoker.run during change column default, since its not needed to create alternate lhm table for this.
  def self.change_table(table_name, options = {}, &block)
    origin = Table.parse(table_name, connection)
    invoker = Invoker.new(origin, connection)
    block.call(invoker.migrator)
    invoker.run(options) unless invoker.migrator.statements.empty?
    true
  end

  class Migrator

    #Overridden this method to 'add column' instead of 'change column' in the ddl statement.
    def rename_column(old, nu)
      col = @origin.columns[old.to_s]

      definition = col[:type]
      definition += ' NOT NULL' unless col[:is_nullable]
      definition += " DEFAULT #{@connection.quote_value(col[:column_default])}" if col[:column_default]
      ddl('alter table `%s` add column `%s` %s' % [@name, nu, definition])
      @renames[old.to_s] = nu.to_s
    end

    #New method to change the default column, by recording the statement and running it at the end of indexing
    def change_column_default(name, default_value)
      change_default_value_statement = ["alter table `%s` alter `%s` set default '%s'" % [@origin.name, name, default_value]]
      DelayedCustomMigrator.record_statements_to_be_delayed(change_default_value_statement)
    end

    #New method to remove the column default value and set it to NULL. Record this statement and run it at the end.
    def drop_column_default(name)
      drop_default_value_statement = ["alter table `%s` alter `%s` set default NULL" % [@origin.name, name]]
      DelayedCustomMigrator.record_statements_to_be_delayed(drop_default_value_statement)
    end
  end

  class DelayedCustomMigrator
    #Record statements in a file to be run at the end of indexing during deployment
    def self.record_statements_to_be_delayed(statements)
      f = File.open(LhmConstants::LHM_MIGRATION_STATEMENTS, "a")
      f.write(statements.join(",") + ",")
      f.close
    end
  end

  class AtomicSwitcher

    #We record statements to run after indexing, and also creating triggers for copying data to the new column from old column
    def statements_for_column_rename
      DelayedCustomMigrator.record_statements_to_be_delayed(cleanup_statements_for_column_rename)
      [
        "create trigger #{insert_trigger_for_column_rename} before insert on #{original_table_name} for each row set #{'NEW.'+new_column_name} = #{'NEW.'+old_column_name}",
        "create trigger #{update_trigger_for_column_rename} before update on #{original_table_name} for each row set #{'NEW.'+new_column_name} = #{'NEW.'+old_column_name}"
      ]
    end

    def insert_trigger_for_column_rename
      "lhmt_ins_rename_#{@origin.name}"
    end

    def update_trigger_for_column_rename
      "lhmt_upd_rename_#{@origin.name}"
    end

    def old_column_name
      @migration.renames.keys.first
    end

    def new_column_name
      @migration.renames.values.first
    end

    def original_table_name
      @origin.name
    end

    #Statements to cleanup triggers and remove the old column to be run after indexing
    def cleanup_statements_for_column_rename
      [
        "drop trigger if exists #{insert_trigger_for_column_rename}",
        "drop trigger if exists #{update_trigger_for_column_rename}",
        "alter table #{original_table_name} drop column #{old_column_name}"
      ]
    end

  end
end

Lhm::Migration.prepend(LhmMigrationWithTruncation)
Lhm::AtomicSwitcher.prepend(LhmAtomicSwitcherWithTriggerRenameColumn)