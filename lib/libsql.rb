require 'ffi'

module CLibsql # :nodoc:
  extend FFI::Library

  lib = File.expand_path('lib/universal2-apple-darwin/liblibsql.dylib', __dir__)
  ffi_lib lib

  Cypher = enum(:default, :aes256)
  Type = enum(
    :integer, 1,
    :real, 2,
    :text, 3,
    :blob, 4,
    :null, 5
  )

  module Verify # :nodoc:
    def verify
      return if self[:err].null?

      s = CLibsql.libsql_error_message self[:err]
      CLibsql.libsql_error_deinit self[:err]
      raise CLibsql.libsql_error_message s
    end
  end

  class Database < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer
  end

  class Connection < FFI::Struct  # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer
  end

  class Transaction < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer
  end

  class Statement < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer
  end

  class Rows < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def next
      CLibsql.libsql_rows_next self
    end
  end

  class Row < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def empty?
      CLibsql.libsql_row_empty self
    end
  end

  class DatabaseDesc < FFI::Struct # :nodoc:
    layout url: :pointer,
           path: :pointer,
           auth_token: :pointer,
           encryption_key: :pointer,
           sync_inteval: :uint64,
           cypher: Cypher,
           disable_read_your_writes: :bool,
           webpki: :bool
  end

  class Bind < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer
  end

  class Execute < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           rows_changed: :uint64
  end

  class Slice < FFI::Struct # :nodoc:
    layout ptr: :pointer,
           len: :size_t
  end

  class ValueUnion < FFI::Union # :nodoc:
    layout integer: :uint64,
           real: :double,
           text: Slice.by_value,
           blob: Slice.by_value
  end

  class Value < FFI::Struct # :nodoc:
    layout value: ValueUnion.by_value,
           type: Type
  end

  class ResultValue < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           ok: Value.by_value
  end

  attach_function :libsql_database_init, [DatabaseDesc.by_value], Database.by_value
  attach_function :libsql_database_sync, [Database.by_value], Database.by_value
  attach_function :libsql_database_connect, [Database.by_value], Connection.by_value

  attach_function :libsql_connection_transaction, [Connection.by_value], Transaction.by_value
  attach_function :libsql_connection_prepare, [Connection.by_value, :string], Statement.by_value

  attach_function :libsql_statement_bind_value, [Statement.by_value, Value.by_value], Bind.by_value
  attach_function :libsql_statement_bind_named, [Statement.by_value, :string, Value.by_value], Bind.by_value
  attach_function :libsql_statement_query, [Statement.by_value], Rows.by_value
  attach_function :libsql_statement_execute, [Statement.by_value], Execute.by_value

  attach_function :libsql_rows_next, [Rows.by_value], Row.by_value

  attach_function :libsql_row_empty, [Row.by_value], :bool
  attach_function :libsql_row_value, [Row.by_value, :uint32], ResultValue.by_value
  attach_function :libsql_row_name, [Row.by_value, :uint32], Slice.by_value
  attach_function :libsql_row_length, [Row.by_value, :uint32], Slice.by_value

  attach_function :libsql_integer, [:int64], Value.by_value
  attach_function :libsql_real, [:double], Value.by_value
  attach_function :libsql_text, %i[pointer size_t], Value.by_value
  attach_function :libsql_blob, %i[pointer size_t], Value.by_value
  attach_function :libsql_null, [], Value.by_value

  attach_function :libsql_error_message, [:pointer], :string

  attach_function :libsql_error_deinit, [:pointer], :void
  attach_function :libsql_row_deinit, [Row.by_value], :void
  attach_function :libsql_rows_deinit, [Rows.by_value], :void
  attach_function :libsql_statement_deinit, [Statement.by_value], :void
  attach_function :libsql_connection_deinit, [Connection.by_value], :void
  attach_function :libsql_database_deinit, [Database.by_value], :void
end

module Libsql
  class Row
    def initialize(inner)
      @inner = inner
    end

    def [](index)
      result = CLibsql.libsql_row_value @inner, index
      result.verify

      type = result[:ok][:type]
      value = result[:ok][:value]

      case type
      in :null then nil
      in :integer then value[:integer]
      in :real then value[:real]
      in :text then value[:text][:ptr].read_string
      in :blob then Blob.new value[:blob][:ptr].read_string(value[:blob][:len])
      end
    end

    def close
      CLibsql.libsql_row_deinit @inner
    end
  end

  class Rows
    def initialize(inner)
      @inner = inner
      @inner.verify
    end

    def next
      row = CLibsql.libsql_rows_next @inner
      row.verify

      Row.new row unless row.empty?
    end

    def each
      while (row = self.next)
        yield row
        row.close
      end
    end

    def close
      CLibsql.libsql_rows_deinit @inner
    end
  end

  class Blob < String; end

  class Statement
    def initialize(inner)
      @inner = inner
      @inner.verify
    end

    def bind(params)
      case params
      in Array
        params.each do |v|
          CLibsql.libsql_statement_bind_value(@inner, convert(v)).verify
        end
      in Hash
        params.each do |name, v|
          CLibsql.libsql_statement_bind_named(@inner, name, convert(v)).verify
        end
      end
    end

    def execute(params = [])
      bind params

      CLibsql.libsql_statement_execute(@inner).verify
    end

    def query(params = [])
      bind params

      Rows.new CLibsql.libsql_statement_query @inner
    end

    def close
      CLibsql.libsql_statement_deinit @inner
    end

    def convert(value)
      case value
      in nil then CLibsql.libsql_null
      in Integer then CLibsql.libsql_integer value
      in Float then CLibsql.libsql_real value
      in String then CLibsql.libsql_text value, value.length
      in Blob then CLibsql.libsql_blob value, value.length
      end
    end
  end

  class Connection
    def initialize(inner)
      @inner = inner
      @inner.verify
    end

    def prepare(sql)
      Statement.new CLibsql.libsql_connection_prepare @inner, sql
    end

    def close
      CLibsql.libsql_connection_deinit @inner
    end
  end

  class Database
    def initialize(options = {})
      desc = CLibsql::DatabaseDesc.new

      %i[path url auth_token encryption_key].each do |sym|
        desc[sym] = FFI::MemoryPointer.from_string options[sym] if options[sym]
      end

      @inner = CLibsql.libsql_database_init(desc)
      @inner.verify

      return unless block_given?

      begin yield self ensure close end
    end

    def connect
      Connection.new CLibsql.libsql_database_connect @inner
    end

    def close
      CLibsql.libsql_database_deinit @inner
    end
  end
end

Libsql::Database.new path: ':memory:' do |db|
  conn = db.connect

  conn.prepare('select ?, ?, ?').query([20, 0.3, 'hello']).each do |row|
    p row[0]
    p row[1]
    p row[2]
  end

  conn.close
end
