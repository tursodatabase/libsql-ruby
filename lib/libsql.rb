require 'ffi'

module CLibsql # :nodoc:
  extend FFI::Library

  file =
    case RUBY_PLATFORM
    in /darwin/ then 'universal2-apple-darwin/liblibsql.dylib'
    in /x86_64-linux/ then 'x86_64-unknown-linux-gnu/liblibsql.so'
    in /arm64-linux/ then 'aarch64-unknown-linux-gnu/liblibsql.so'
    end

  ffi_lib File.expand_path("lib/#{file}", __dir__)

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

    def deinit
      CLibsql.libsql_database_deinit self
    end
  end

  class Connection < FFI::Struct  # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def deinit
      CLibsql.libsql_connection_deinit self
    end
  end

  class Transaction < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def deinit
      CLibsql.libsql_transaction_deinit self
    end
  end

  class Statement < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def bind_value(value)
      CLibsql.libsql_statement_bind_value(self, value).verify
    end

    def bind_named(name, value)
      CLibsql.libsql_statement_bind_named(self, name, value).verify
    end

    def deinit
      CLibsql.libsql_statement_deinit self
    end
  end

  class Rows < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def next
      CLibsql.libsql_rows_next self
    end

    def deinit
      CLibsql.libsql_rows_deinit self
    end
  end

  class Row < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def value_at(index)
      CLibsql.libsql_row_value self, index
    end

    def name_at(index)
      CLibsql.libsql_row_name self, index
    end

    def length
      CLibsql.libsql_row_length self
    end

    def empty?
      CLibsql.libsql_row_empty self
    end

    def deinit
      CLibsql.libsql_row_deinit self
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

    def to_blob
      b = Blob.new self[:ptr].read_string self[:len]
      deinit
      b
    end

    def to_s
      s = self[:ptr].read_string
      deinit
      s
    end

    def deinit
      CLibsql.libsql_slice_deinit self
    end
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

    def convert
      case self[:type]
      in :null then nil
      in :integer then self[:value][:integer]
      in :real then self[:value][:real]
      in :text then self[:value][:text].to_s
      in :blob then self[:value][:blob].to_blob
      end
    end
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
  attach_function :libsql_row_length, [Row.by_value], :uint32

  attach_function :libsql_integer, [:int64], Value.by_value
  attach_function :libsql_real, [:double], Value.by_value
  attach_function :libsql_text, %i[pointer size_t], Value.by_value
  attach_function :libsql_blob, %i[pointer size_t], Value.by_value
  attach_function :libsql_null, [], Value.by_value

  attach_function :libsql_error_message, [:pointer], :string

  attach_function :libsql_error_deinit, [:pointer], :void
  attach_function :libsql_slice_deinit, [Row.by_value], :void
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

    def to_a
      (0...@inner.length).map { |i| self[i] }
    end

    def to_h
      cols.zip(to_a).to_h
    end

    def cols
      (0...@inner.length).map { |i| @inner.name_at(i).to_s }
    end

    def [](index)
      result = @inner.value_at index
      result.verify
      result[:ok].convert
    end

    def close
      @inner.deinit
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
      @inner.deinit
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
      in Array then params.each { |v| @inner.bind_value convert(v) }
      in Hash then params.each do |k, v|
        @inner.bind_named case k when Symbol then ":#{k}" else k end, convert(v)
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
      @inner.deinit
    end

    private

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
      @inner.deinit
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
      @inner.deinit
    end
  end
end

Libsql::Database.new path: ':memory:' do |db|
  conn = db.connect

  conn.prepare('select :a, :b, :c, :d').query({ a: 20, b: 0.3, c: 'hello', d: nil }).each do |row|
    p row.cols
    p row.to_a
  end

  conn.close
end
