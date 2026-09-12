require 'test_helper'

class ConnectionTest < Minitest::Test
  include BocdTestHelper

  def test_roundtrip_with_multibyte_payload
    server = FakeFrontend.new { |xml| "<ap><head><ret_info>收到#{xml.bytesize}字节</ret_info></head><body/></ap>" }
    connection = Bocd::Connection.new(host: '127.0.0.1', port: server.port, read_timeout: 5)

    request = Bocd::Message.build('X', { summary: '中文' })
    response = connection.call(request)

    assert_equal Encoding::UTF_8, response.encoding
    assert_includes response, "收到#{request.bytesize - 10}字节"
  ensure
    server&.close
  end

  def test_connection_refused_raises_connection_error
    # 拿一个刚释放的端口，确保无人监听
    probe = TCPServer.new('127.0.0.1', 0)
    port = probe.addr[1]
    probe.close

    connection = Bocd::Connection.new(host: '127.0.0.1', port: port, connect_timeout: 2)
    error = assert_raises(Bocd::ConnectionError) { connection.call('0000000009<ap></ap>') }
    assert_match(/连接前置机/, error.message)
  end

  def test_invalid_length_prefix_raises_protocol_error
    server = FakeFrontend.new { |_xml| [:raw, 'garbage-prefix-no-digits'] }
    connection = Bocd::Connection.new(host: '127.0.0.1', port: server.port, read_timeout: 5)

    assert_raises(Bocd::ProtocolError) { connection.call(Bocd::Message.build('X', {})) }
  ensure
    server&.close
  end

  def test_reads_response_delivered_in_chunks
    xml = "<ap><head><ret_code>0000</ret_code></head><body>#{'x' * 300}</body></ap>"
    # 自定义分包服务端：先发长度前缀，再分三段慢发报文
    chunked = TCPServer.new('127.0.0.1', 0)
    thread = Thread.new do
      sock = chunked.accept
      length = sock.read(10).to_i
      sock.read(length)
      sock.write(format('%010d', xml.bytesize))
      xml.b.chars.each_slice(150) do |slice|
        sock.write(slice.join)
        sleep 0.05
      end
      sock.close
    end

    connection = Bocd::Connection.new(host: '127.0.0.1', port: chunked.addr[1], read_timeout: 5)
    response = connection.call(Bocd::Message.build('X', {}))

    assert_equal xml, response
  ensure
    thread&.kill
    chunked&.close
  end

  def test_read_timeout_raises_connection_error
    silent = TCPServer.new('127.0.0.1', 0)
    thread = Thread.new do
      sock = silent.accept
      sleep 10 # 收下请求但不应答
      sock.close
    end

    connection = Bocd::Connection.new(host: '127.0.0.1', port: silent.addr[1], read_timeout: 0.2, write_timeout: 2)
    error = assert_raises(Bocd::ConnectionError) { connection.call(Bocd::Message.build('X', {})) }
    assert_match(/超时/, error.message)
  ensure
    thread&.kill
    silent&.close
  end

  def test_premature_close_raises_connection_error
    truncating = TCPServer.new('127.0.0.1', 0)
    thread = Thread.new do
      sock = truncating.accept
      length = sock.read(10).to_i
      sock.read(length)
      sock.write('0000000500<ap>') # 声明 500 字节但只发一点就断开
      sock.close
    end

    connection = Bocd::Connection.new(host: '127.0.0.1', port: truncating.addr[1], read_timeout: 2)
    error = assert_raises(Bocd::ConnectionError) { connection.call(Bocd::Message.build('X', {})) }
    assert_match(/提前关闭/, error.message)
  ensure
    thread&.kill
    truncating&.close
  end
end
