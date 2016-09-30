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
  attach_function :redisCommand, [:pointer, :string, :varargs], :pointer, :blocking => true
  attach_function :redisFree, [:pointer], :void, :blocking => true # :pointer => redisContext from redisConnect


  attach_function :redisClusterFree, [:pointer], :void, :blocking => true
  attach_function :redisClusterConnect, [:string, :int], :pointer, :blocking => true # string => addresses, :int => flags
  attach_function :redisClusterConnectNonBlock, [:string, :int], :pointer, :blocking => true
  attach_function :redisClusterCommand, [:pointer, :string, :varargs], :pointer, :blocking => true

  def self.test_set_get
    connection = FFIHIREDISVIP.redisConnect("127.0.0.1", 6379)

    reply_raw = FFIHIREDISVIP.redisCommand(connection, "SET %b %b", :string, "bar", :size_t, 3, :string, "hello", :size_t, 5)
    FFIHIREDISVIP.freeReplyObject(reply_raw)

    get_reply_raw = FFIHIREDISVIP.redisCommand(connection, "GET bar")
    FFIHIREDISVIP.freeReplyObject(get_reply_raw)

    FFIHIREDISVIP.redisFree(connection)
  end
end
