# sanitize_sql is a protected classmethod, making it really
# difficult to do raw SQL queries.  This is a horrible workaround
arb = ActiveRecord::Base
def arb.sanitize_the_sql(*args)
  sanitize_sql(*args)
end
