require_relative '../lib/libsql'

db =
  Libsql::Database.new(
    path: 'local.db',
    url: ENV['TURSO_DATABASE_URL'],
    auth_token: ENV['TURSO_AUTH_TOKEN'],
    sync_interval: 100
  )

db.sync

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
