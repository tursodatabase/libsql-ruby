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

    def self.init(desc) = CLibsql.libsql_database_init(desc).tap(&:verify)
    def sync = CLibsql.libsql_database_sync(self).tap(&:verify)
    def connect = CLibsql.libsql_database_connect(self).tap(&:verify)
    def deinit = CLibsql.libsql_database_deinit self
  end

  class Connection < FFI::Struct  # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def transaction = CLibsql.libsql_connection_transaction(self).tap(&:verify)
    def prepare(sql) = CLibsql.libsql_connection_prepare(self, sql).tap(&:verify)
    def execute_batch(sql) = CLibsql.libsql_connection_batch(self, sql).tap(&:verify)
    def deinit = CLibsql.libsql_connection_deinit self
  end

  class Transaction < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def commit = CLibsql.libsql_transaction_commit(self)
    def rollback = CLibsql.libsql_transaction_rollback(self)
    def prepare(sql) = CLibsql.libsql_transaction_prepare(self, sql).tap(&:verify)
    def execute_batch(sql) = CLibsql.libsql_transaction_batch(self, sql).tap(&:verify)
    def deinit = CLibsql.libsql_transaction_deinit self
  end

  class Statement < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def bind_value(value) = CLibsql.libsql_statement_bind_value(self, value).tap(&:verify)
    def bind_named(name, value) = CLibsql.libsql_statement_bind_named(self, name, value).tap(&:verify)
    def query = CLibsql.libsql_statement_query(self).tap(&:verify)
    def execute = CLibsql.libsql_statement_execute(self).tap(&:verify)
    def deinit = CLibsql.libsql_statement_deinit self
  end

  class Rows < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def next = CLibsql.libsql_rows_next(self).tap(&:verify)
    def deinit = CLibsql.libsql_rows_deinit(self)
  end

  class Row < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           inner: :pointer

    def value_at(index) = CLibsql.libsql_row_value(self, index).tap(&:verify)
    def name_at(index) = CLibsql.libsql_row_name(self, index)
    def length = CLibsql.libsql_row_length(self)
    def empty? = CLibsql.libsql_row_empty(self)
    def deinit = CLibsql.libsql_row_deinit(self)
  end

  class DatabaseDesc < FFI::Struct # :nodoc:
    layout url: :pointer,
           path: :pointer,
           auth_token: :pointer,
           encryption_key: :pointer,
           sync_interval: :uint64,
           cypher: Cypher,
           disable_read_your_writes: :bool,
           webpki: :bool
  end

  class Bind < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer
  end

  class Batch < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer
  end

  class Sync < FFI::Struct # :nodoc:
    include Verify

    layout err: :pointer,
           frame_no: :uint64,
           frames_synced: :uint64
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

    def deinit = CLibsql.libsql_slice_deinit self
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

  class Config < FFI::Struct # :nodoc:
    include Verify

    layout logger: :pointer,
           version: :pointer
  end

  attach_function :libsql_setup, [Config.by_value], :pointer

  attach_function :libsql_database_init, [DatabaseDesc.by_value], Database.by_value
  attach_function :libsql_database_sync, [Database.by_value], Sync.by_value
  attach_function :libsql_database_connect, [Database.by_value], Connection.by_value

  attach_function :libsql_connection_transaction, [Connection.by_value], Transaction.by_value
  attach_function :libsql_connection_prepare, [Connection.by_value, :string], Statement.by_value
  attach_function :libsql_connection_batch, [Connection.by_value, :string], Batch.by_value

  attach_function :libsql_transaction_prepare, [Transaction.by_value, :string], Statement.by_value
  attach_function :libsql_transaction_commit, [Transaction.by_value], :void
  attach_function :libsql_transaction_rollback, [Transaction.by_value], :void
  attach_function :libsql_transaction_batch, [Transaction.by_value, :string], Batch.by_value

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
  class Blob < String; end

  module Prepareable
    def execute(sql, params = [])
      prepare(sql) { |stmt| stmt.execute(params) }
    end

    def query(sql, params = [])
      prepare(sql) { |stmt| stmt.query(params) }
    end
  end

  class Row
    include Enumerable

    def initialize(inner)
      @inner = inner
    end

    def to_h = columns.zip(to_a).to_h
    def length = @inner.length
    def columns = (0...length).map { |i| @inner.name_at(i).to_s }
    def each = (0...length).each { |i| yield self[i] }

    def [](index)
      case index
      in Integer then @inner.value_at(index)[:ok].convert
      in String
        at = columns.index(index)
        return self[at] unless at.nil?

        raise "#{index} is not a valid row column"
      end
    end

    def close = @inner.deinit
  end

  class Rows
    include Enumerable

    def initialize(inner)
      @inner = inner
    end

    def to_a
      map(&:to_h)
    end

    def next
      row = @inner.next
      Row.new row unless row.empty?
    end

    def each
      while (row = self.next)
        yield row
        row.close
      end
    end

    def close = @inner.deinit
  end

  class Statement
    def initialize(inner)
      @inner = inner
    end

    def bind(params)
      case params
      in Array then params.each { |v| @inner.bind_value convert(v) }
      in Hash
        params.each do |k, v|
          @inner.bind_named case k when Symbol then ":#{k}" else k end, convert(v)
        end
      end
    end

    def execute(params = [])
      bind params
      @inner.execute
    end

    def query(params = [])
      bind params
      rows = Rows.new @inner.query
      return rows unless block_given?

      begin yield rows ensure fows.close end
    end

    def close = @inner.deinit

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

  class Transaction
    include Prepareable

    def initialize(inner)
      @inner = inner
    end

    def prepare(sql)
      stmt = Statement.new @inner.prepare sql
      return stmt unless block_given?

      begin yield stmt ensure stmt.close end
    end

    def execute_batch(sql) = @inner.execute_batch(sql)

    def rollback = @inner.rollback
    def commit = @inner.commit
  end

  class Connection
    include Prepareable

    def initialize(inner)
      @inner = inner
    end

    def transaction
      tx = Transaction.new @inner.transaction
      return tx unless block_given?

      abort = false
      begin
        yield self
      rescue StandardError
        abort = true
        raise
      ensure
        abort and tx.rollback or tx.commit
      end
    end

    def prepare(sql)
      stmt = Statement.new @inner.prepare sql

      return stmt unless block_given?

      begin yield stmt ensure stmt.close end
    end

    def execute_batch(sql) = @inner.execute_batch(sql)

    def close = @inner.deinit
  end

  class Database
    def initialize(options = {})
      desc = CLibsql::DatabaseDesc.new

      %i[path url auth_token encryption_key].each do |sym|
        desc[sym] = FFI::MemoryPointer.from_string options[sym] unless options[sym].nil?
      end

      desc[:sync_interval] = options[:sync_interval] unless options[:sync_interval].nil?
      desc[:disable_read_your_writes] = !options[:read_your_writes] unless options[:read_your_writes].nil?

      @inner = CLibsql::Database.init desc

      return unless block_given?

      begin yield self ensure close end
    end

    def sync
      @inner.sync
    end

    def connect
      conn = Connection.new @inner.connect

      return unless block_given?

      begin yield conn ensure conn.close end
    end

    def close = @inner.deinit
  end
end

config = CLibsql::Config.new
config[:version] = FFI::MemoryPointer.from_string 'libsql-ruby'
CLibsql.libsql_setup config
