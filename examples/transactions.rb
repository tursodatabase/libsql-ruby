require_relative '../lib/libsql'

db = Libsql::Database.new(path: 'local.db')

db.connect do |conn|
  conn.execute_batch <<-SQL
    DROP TABLE IF EXISTS users;
    CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT);
    INSERT INTO users (name) VALUES ('Iku Turso');
  SQL

  names = ['John Doe', 'Mary Smith', 'Alice Jones', 'Mark Taylor']

  tx = conn.transaction
  names.each { |name| tx.execute 'INSERT INTO users (name) VALUES (?)', [name] }
  tx.rollback

  tx = conn.transaction
  names.each { |name| tx.execute 'INSERT INTO users (name) VALUES (?)', [name] }
  tx.commit

  rows = conn.query 'SELECT * FROM users'
  print "Users: #{rows.to_a}\n"
  rows.close
end
