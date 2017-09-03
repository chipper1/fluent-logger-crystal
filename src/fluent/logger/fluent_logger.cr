require "msgpack"
require "./logger_base"
require "socket"

module Fluent::Logger
  class EventTime
    TYPE = 0

    def initialize(@time)
    end

    def to_msgpack(io = nil)
      @time.to_i.to_msgpack io
    end

    def to_msgpack_ext
      [@time.to_i, @time.nsec].pack("NN")
    end

    def self.from_msgpack_ext(data)
      new(*data.unpack "NN")
    end

    def to_json(*args)
      @time.to_i
    end
  end

  class FluentLogger < LoggerBase
    BUFFER_LIMIT = 8*1024*1024
    #RECONNECT_WAIT = 0.5
    #RECONNECT_WAIT_INCR_RATE = 1.5
    #RECONNECT_WAIT_MAX = 60

    getter conn : Socket?

    def initialize(
        @tag_prefix : String? = nil,
        @host = "localhost",
        @port = 24224,
        @socket_path : String? = nil,
        @limit : Int32 = BUFFER_LIMIT
      )
      @time_format = "%b %e %H:%M:%S"
      #@pending = nil
      @last_error = Hash(UInt64, Exception).new
    end

    def post_with_time(tag, map, time)
      tag = "#{@tag_prefix}.#{tag}" if @tag_prefix
      write [tag, time.second, map]
    end

    def close
      #if !@pending.nil?
      #  send_data @pending
      #end
      @conn.close if connect?
      @conn = nil
      #@pending = nil
    end

    def write(msg)
      begin
        data = msg.to_msgpack
        send_data data
        true
      rescue e
        @conn.as(Socket).close if connect?
        @conn = nil
        false
      end
    end

    def send_data(data)
      unless connect?
        connect!
      end
      @conn.as(Socket).write data
      true
    end

    def create_socket!
      path = @socket_path
      @conn = if !path.nil?
        UNIXSocket.new(path)
      else
        TCPSocket.new(@host, @port)
      end
    end

    def connect?
      !@conn.nil? && !@conn.as(Socket).closed?
    end

    def connect!
      create_socket!
      @conn.as(Socket).sync = true if !@conn.nil?
    rescue e
      puts e.message
      raise e
    end

    def set_last_error(e)
      @last_error[Fiber.current.object_id] = e
    end
  end
end
