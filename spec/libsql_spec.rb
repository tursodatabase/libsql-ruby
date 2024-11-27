require_relative '../lib/libsql'

RSpec.describe do
  turso_url = `turso db show --url ruby-test`.strip
  turso_auth_token = `turso db tokens create -e 1d ruby-test`.strip

  db =
    Libsql::Database.new(
      path: 'test.db',
      url: turso_url,
      auth_token: turso_auth_token,
      sync_interval: 100
    )

  it 'create, insert, select table' do
    db.connect do |conn|
      conn.execute_batch <<-SQL
        drop table if exists test;
        create table test (i integer);
      SQL

      (0..10).each do |i|
        conn.query 'insert into test values (:i)', { i: }
      end

      (0..10).zip(conn.query('select * from test').map { |row| row['i'] }) do |expected, have|
        expect(have).to eq(expected)
      end
    end
  end
end
