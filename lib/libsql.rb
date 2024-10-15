
require 'ffi';

module CLibsql
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

  class Rows < FFI::Struct
    layout :err => :pointer,
           :inner => :pointer
  end

  class Row < FFI::Struct
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

  class Bind < FFI::Struct
    layout :err => :pointer
  end

  class Execute < FFI::Struct
    layout :err => :pointer,
           :rows_changed => :uint64
  end

  class Slice < FFI::Struct
    layout :ptr => :pointer,
           :len => :size_t
  end

  class ValueUnion < FFI::Union
    layout :integer => :uint64,
           :real => :double,
           :text => Slice.by_value,
           :blob => Slice.by_value
  end

  class Value < FFI::Struct
    layout :value => ValueUnion.by_value,
           :type => Type
  end

  class ResultValue < FFI::Struct
    layout :err => :pointer,
           :ok => Value.by_value
  end

  attach_function :libsql_database_init, [DatabaseDesc.by_value], Database.by_value
  attach_function :libsql_database_deinit, [Database.by_value], :void
  attach_function :libsql_database_sync, [Database.by_value], Database.by_value
  attach_function :libsql_database_connect, [Database.by_value], Connection.by_value

  attach_function :libsql_connection_deinit, [Connection.by_value], :void
  attach_function :libsql_connection_transaction, [Connection.by_value], Transaction.by_value
  attach_function :libsql_connection_prepare, [Connection.by_value, :string], Statement.by_value

  attach_function :libsql_statement_bind_value, [Statement.by_value, Value.by_value], Bind.by_value
  attach_function :libsql_statement_bind_named, [Statement.by_value, :string, Value.by_value], Bind.by_value
  attach_function :libsql_statement_query, [Statement.by_value], Rows.by_value
  attach_function :libsql_statement_execute, [Statement.by_value], Execute.by_value

  attach_function :libsql_rows_next, [Rows.by_value], Row.by_value

  attach_function :libsql_row_value, [Row.by_value, :uint32], ResultValue.by_value

  attach_function :libsql_error_message, [:pointer], :string
end

desc = CLibsql::DatabaseDesc.new

db = CLibsql.libsql_database_init(desc)
raise CLibsql.libsql_error_message(db[:err]) if db[:err] != nil

conn = CLibsql.libsql_database_connect(db)
raise CLibsql.libsql_error_message(conn[:err]) if conn[:err] != nil

stmt = CLibsql.libsql_connection_prepare(conn, "select 20")
raise CLibsql.libsql_error_message(stmt[:err]) if stmt[:err] != nil

rows = CLibsql.libsql_statement_query(stmt)
raise CLibsql.libsql_error_message(rows[:err]) if rows[:err] != nil

row = CLibsql.libsql_rows_next(rows)
raise CLibsql.libsql_error_message(row[:err]) if row[:err] != nil

puts CLibsql.libsql_row_value(row, 0)[:ok].values
puts CLibsql.libsql_row_value(row, 0)[:ok][:value].values

puts conn.values
