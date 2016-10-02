require 'rubygems'
require 'ffi'

module FFIHIREDISVIP
  extend FFI::Library
  ffi_lib_flags :now, :global
  ffi_lib File.expand_path("./libhiredis_vip.#{FFI::Platform::LIBSUFFIX}", File.dirname(__FILE__))

  RedisReplyType = enum :REDIS_REPLY_STRING, 1,
                        :REDIS_REPLY_ARRAY, 2,
                        :REDIS_REPLY_INTEGER, 3,
                        :REDIS_REPLY_NIL, 4,
                        :REDIS_REPLY_STATUS, 5,
                        :REDIS_REPLY_ERROR, 6

  RedisOkType = enum :REDIS_OK, 0,
                     :REDIS_ERR, -1,
                     :REDIS_ERR_IO, 1, # /* Error in read or write */
                     :REDIS_ERR_OTHER, 2, # /* Everything else... */
                     :REDIS_ERR_EOF, 3, # /* End of file */
                     :REDIS_ERR_PROTOCOL, 4, # /* Protocol error */
                     :REDIS_ERR_OOM, 5, # /* Out of memory */
                     :REDIS_ERR_CLUSTER_TOO_MANY_REDIRECT, 6

  class Timeval < FFI::Struct
    layout :tv_sec, :long,
           :tv_usec, :long
  end

  class RedisReply < ::FFI::Struct
    layout :type, ::FFIHIREDISVIP::RedisReplyType,
           :integer, :long_long,
           :len, :int,
           :str, :string,
           :elements, :size_t,
           :element, :pointer
  end

  attach_function :freeReplyObject, [:pointer], :void, :blocking => true

  attach_function :redisConnect, [:string, :int], :pointer, :blocking => true
  attach_function :redisReconnect, [:pointer], RedisOkType, :blocking => true # :pointer => redisContext
  attach_function :redisEnableKeepAlive, [:pointer], RedisOkType, :blocking => true # :pointer => redisContext
  attach_function :redisCommand, [:pointer, :string, :varargs], RedisReply.ptr, :blocking => true
  attach_function :redisFree, [:pointer], :void, :blocking => true # :pointer => redisContext from redisConnect

  attach_function :redisClusterFree, [:pointer], :void, :blocking => true # :pointer => redisClusterContext
  attach_function :redisClusterConnect, [:string, :int], :pointer, :blocking => true # string => addresses, :int => flags
  attach_function :redisClusterConnectWithTimeout, [:string, Timeval.by_value, :int], :pointer, :blocking => true # string => addresses, :timeval => timeout, :int => flags
  attach_function :redisClusterConnectNonBlock, [:string, :int], :pointer, :blocking => true
  attach_function :redisClusterCommand, [:pointer, :string, :varargs], :pointer, :blocking => true
  attach_function :redisClusterSetMaxRedirect, [:pointer, :int], :void, :blocking => true # :pointer => redisContext, :int => max redirect
  attach_function :redisClusterReset, [:pointer], :void, :blocking => true # :pointer => redisClusterContext

  def self.bench
    require "benchmark"

    connection = FFIHIREDISVIP.redisConnect("127.0.0.1", 6379)
    n = (ARGV.shift || 20000).to_i

    elapsed = Benchmark.realtime do
      # n sets, n gets
      n.times do |i|
        key = "foo#{i}"
        value = key * 10

        reply_raw = FFIHIREDISVIP.redisCommand(connection, "SET %b %b", :string, key, :size_t, key.size, :string, value, :size_t, value.size)
        FFIHIREDISVIP.freeReplyObject(reply_raw)

        reply = FFIHIREDISVIP.redisCommand(connection, "GET %b", :string, key, :size_t, key.size)
        reply_str = reply[:str]
        raise "probs" unless reply[:str] == value
        FFIHIREDISVIP.freeReplyObject(reply)
        reply_str
      end
    end

    puts '%.2f Kops' % (2 * n / 1000 / elapsed)
  ensure
    FFIHIREDISVIP.redisFree(connection)
  end

  def self.test_set_get
    connection = FFIHIREDISVIP.redisConnect("127.0.0.1", 6379)

    reply_raw = FFIHIREDISVIP.redisCommand(connection, "SET %b %b", :string, "bar", :size_t, 3, :string, "hello", :size_t, 5)
    FFIHIREDISVIP.freeReplyObject(reply_raw)

    get_reply_raw = FFIHIREDISVIP.redisCommand(connection, "GET bar")
    reply = RedisReply.new(get_reply_raw)
    puts reply[:str]
    FFIHIREDISVIP.freeReplyObject(get_reply_raw)

    FFIHIREDISVIP.redisFree(connection)
  end
end
