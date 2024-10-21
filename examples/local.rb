require_relative '../lib/libsql'

db = Libsql::Database.new(path: 'local.db')

db.connect do |conn|
  conn.execute_batch <<-SQL
    CREATE TABLE IF NOT EXISTS users (email TEXT);
    INSERT INTO users VALUES ('first@example.com');
    INSERT INTO users VALUES ('second@example.com');
    INSERT INTO users VALUES ('third@example.com');
  SQL

  rows = conn.query 'SELECT * FROM users'
  print "Users: #{rows.to_a}\n"
  rows.close
end
