require 'socket'

module Bocd
  # 与前置机的 TCP/IP Socket 同步短连接（接口文档 2.1）：每次交易建连 → 发送 → 收完即断
  class Connection
    LENGTH_PREFIX_SIZE = 10

    # IO::TimeoutError 为 Ruby 3.2+ 才有（Socket.tcp connect_timeout 超时抛出）
    CONNECT_ERRORS = [SystemCallError, SocketError].tap do |errors|
      errors << IO::TimeoutError if defined?(IO::TimeoutError)
    end.freeze

    attr_reader :host, :port, :connect_timeout, :read_timeout, :write_timeout

    def initialize(host: nil, port: nil, connect_timeout: nil, read_timeout: nil, write_timeout: nil)
      @host = host || Bocd.host
      @port = port || Bocd.port
      @connect_timeout = connect_timeout || Bocd.connect_timeout
      @read_timeout = read_timeout || Bocd.read_timeout
      @write_timeout = write_timeout || Bocd.write_timeout
    end

    # 发送完整请求报文（含长度前缀），返回应答交易报文（已剥掉长度前缀的 XML 字符串）
    def call(payload)
      socket = connect
      begin
        write(socket, payload.b)
        length = read_length(socket)
        read_exact(socket, length).force_encoding(Encoding::UTF_8)
      ensure
        socket.close rescue nil
      end
    end

    private

    def connect
      Socket.tcp(host, port, connect_timeout: connect_timeout)
    rescue *CONNECT_ERRORS => e
      raise ConnectionError, "连接前置机 #{host}:#{port} 失败: #{e.class} #{e.message}"
    end

    def write(socket, bytes)
      until bytes.empty?
        ready = IO.select(nil, [socket], nil, write_timeout)
        raise ConnectionError, "写入前置机超时(#{write_timeout}s)" unless ready

        written = socket.write_nonblock(bytes, exception: false)
        next if written == :wait_writable

        bytes = bytes.byteslice(written..-1)
      end
    rescue SystemCallError, IOError => e
      raise ConnectionError, "写入前置机失败: #{e.class} #{e.message}"
    end

    def read_length(socket)
      prefix = read_exact(socket, LENGTH_PREFIX_SIZE)
      raise ProtocolError, "应答长度前缀非法: #{prefix.inspect}" unless prefix.match?(/\A\d{10}\z/)

      prefix.to_i
    end

    def read_exact(socket, size)
      buffer = +''
      while buffer.bytesize < size
        ready = IO.select([socket], nil, nil, read_timeout)
        raise ConnectionError, "读取前置机应答超时(#{read_timeout}s)" unless ready

        chunk = socket.read_nonblock(size - buffer.bytesize, exception: false)
        raise ConnectionError, '前置机提前关闭连接' if chunk.nil?
        next if chunk == :wait_readable

        buffer << chunk
      end
      buffer
    rescue SystemCallError, IOError => e
      raise ConnectionError, "读取前置机应答失败: #{e.class} #{e.message}"
    end
  end
end
