require_relative '../lib/libsql'

RSpec.describe do
  turso_url = ENV['TURSO_URL']
  turso_auth_token = ENV['TURSO_AUTH_TOKEN']

  db =
    Libsql::Database.new(
      path: 'test.db',
      url: turso_url,
      auth_token: turso_auth_token,
      read_your_writes: false,
      sync_interval: 100
    )

  it 'create, insert, select table' do
    db.connect do |conn|
      conn.execute_batch <<-SQL
        drop table if exists test;
        create table test (i integer);
      SQL

      (0..10).each do |i|
        conn.execute 'insert into test values (:i)', { i: }
      end

      db.sync

      (0..10).zip(conn.query('select * from test').map { |row| row['i'] }) do |expected, have|
        expect(have).to eq(expected)
      end

      expect(conn.total_changes).to eq(11)
      expect(conn.last_inserted_id).to eq(11)
    end
  end

  it 'delete local' do
    db = Libsql::Database.new(path: 'local_test.db')

    project_id = 1
    key_type = 'test'
    key = 'test'

    db.connect do |conn|
      sql = <<~SQL
        CREATE TABLE IF NOT EXISTS keys(
          project_id INTEGER NOT NULL,
          key_type TEXT NOT NULL,
          key TEXT NOT NULL
        )
      SQL
      conn.query(sql) {}
    end

    db.connect do |conn|
      sql = 'INSERT INTO keys(`project_id`, `key_type`, `key`) VALUES(?, ?, ?);'
      conn.query(sql, [project_id, key_type, key]) {}
    end

    db.connect do |conn|
      count = conn.query('SELECT COUNT(*) FROM keys') { |rows| rows.first.first }
      expect(count).to eq(1)
    end

    db.connect do |conn|
      sql = 'DELETE FROM `keys` WHERE `project_id` = ? AND `key_type` = ? AND `key` = ?'
      conn.execute(sql, [project_id, key_type, key]) {}
    end

    db.connect do |conn|
      count = conn.query('SELECT COUNT(*) FROM keys;') { |rows| rows.first.first }
      expect(count).to eq(0)
    end
  end

  describe 'Connection#transaction' do
    context 'when there is an exception' do
      it 'aborts the transaction and raises the exception' do
        exception_class = Class.new(StandardError)

        db.connect do |conn|
          expect { conn.transaction { raise exception_class } }.to raise_error(exception_class)
        end
      end
    end
  end
end
