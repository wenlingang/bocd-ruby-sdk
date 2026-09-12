$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'bocd'

require 'minitest/autorun'
require 'socket'

Bocd.configure { |c| c.logger = Logger.new(IO::NULL) }

module BocdTestHelper
  # 线程内假前置机：按协议收一笔请求（10 位长度前缀 + XML），由 handler 决定应答。
  # handler 返回 String 时自动加长度前缀；返回 [:raw, bytes] 时原样写出（用于测试协议异常）。
  class FakeFrontend
    attr_reader :port, :requests

    def initialize(&handler)
      @handler = handler
      @requests = Queue.new
      @server = TCPServer.new('127.0.0.1', 0)
      @port = @server.addr[1]
      @accept_thread = Thread.new { serve }
    end

    def serve
      loop do
        client = @server.accept
        Thread.new(client) { |sock| handle(sock) }
      end
    rescue IOError, Errno::EBADF
      # server closed
    end

    def handle(sock)
      length = sock.read(10).to_i
      xml = sock.read(length).force_encoding(Encoding::UTF_8)
      @requests << xml
      response = @handler.call(xml)
      if response.is_a?(Array) && response.first == :raw
        sock.write(response.last)
      elsif response
        body = response.b
        sock.write(format('%010d', body.bytesize) + body)
      end
    rescue IOError, Errno::EBADF, Errno::EPIPE, Errno::ECONNRESET
      # client gone
    ensure
      sock.close rescue nil
    end

    def received
      @requests.pop(true)
    rescue ThreadError
      nil
    end

    def close
      @server.close rescue nil
      @accept_thread.kill
    end
  end

  def with_frontend(handler)
    server = FakeFrontend.new(&handler)
    api = Bocd::Api.new(host: '127.0.0.1', port: server.port, read_timeout: 5, connect_timeout: 2)
    yield server, api
  ensure
    server&.close
  end

  # 从请求 XML 中提取节点文本
  def extract(xml, tag)
    xml[%r{<#{tag}>([^<]*)</#{tag}>}, 1]
  end

  def response_xml(tr_code:, req_no:, ret_code: '0000', ret_info: '交易成功', serial_no: '022202409010000066239', body: '')
    "<ap><head><tr_code>#{tr_code}</tr_code><serial_no>#{serial_no}</serial_no>" \
      "<req_no>#{req_no}</req_no><tr_acdt>20231016</tr_acdt><tr_time>103901</tr_time>" \
      "<ret_code>#{ret_code}</ret_code><ret_info>#{ret_info}</ret_info></head>" \
      "<body>#{body}</body></ap>"
  end

  # 应答 handler：原样回显请求的 tr_code/req_no，body 由 block 或参数给定
  def echo_handler(body: '', ret_code: '0000', ret_info: '交易成功')
    proc do |request_xml|
      body_content = body.respond_to?(:call) ? body.call(request_xml) : body
      response_xml(
        tr_code: extract(request_xml, 'tr_code'),
        req_no: extract(request_xml, 'req_no'),
        ret_code: ret_code,
        ret_info: ret_info,
        body: body_content
      )
    end
  end
end
