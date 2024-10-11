
require 'ffi';

module Libsql
  extend FFI::Library

  lib = File.expand_path('../lib/universal2-apple-darwin/liblibsql.dylib', __FILE__)
  ffi_lib lib

  Cypher = enum(:default, :aes256)
  Type = enum(
    :integer, 1,
    :real, 2,
    :text, 3,
    :blob, 4,
    :null, 5
  )

  class Database < FFI::Struct
    layout :err => :pointer,
           :inner => :pointer
  end

  class Connection < FFI::Struct
    layout :err => :pointer,
           :inner => :pointer
  end

  class Transaction < FFI::Struct
    layout :err => :pointer,
           :inner => :pointer
  end

  class Statement < FFI::Struct
    layout :err => :pointer,
           :inner => :pointer
  end

  class DatabaseDesc < FFI::Struct
    layout :url => :string,
           :path => :string,
           :auth_token => :string,
           :encryption_key => :string,
           :sync_inteval => :uint64,
           :cypher => Cypher,
           :disable_read_your_writes => :bool,
           :webpki => :bool
  end

  attach_function :libsql_database_init, [DatabaseDesc.by_value], Database.by_value
  attach_function :libsql_database_deinit, [Database.by_value], :void
  attach_function :libsql_database_sync, [Database.by_value], Database.by_value
  attach_function :libsql_database_connect, [Database.by_value], Connection.by_value

  attach_function :libsql_connection_deinit, [Connection.by_value], :void
  attach_function :libsql_connection_transaction, [Connection.by_value], Transaction.by_value
  attach_function :libsql_connection_prepare, [Connection.by_value, :string], Statement.by_value

  attach_function :libsql_error_message, [:pointer], :string
end

desc = Libsql::DatabaseDesc.new

db = Libsql.libsql_database_init(desc)
conn = Libsql.libsql_database_connect(db)

puts conn.values
