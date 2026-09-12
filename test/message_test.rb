require 'test_helper'

class MessageTest < Minitest::Test
  include BocdTestHelper

  def test_build_prefixes_byte_length_not_char_length
    payload = Bocd::Message.build('03020101A0008', { acctNo: '123', summary: '中文摘要' })
    prefix = payload[0, 10]
    xml = payload[10..]

    assert_match(/\A\d{10}\z/, prefix)
    assert_equal xml.bytesize, prefix.to_i
    refute_equal xml.length, xml.bytesize, '用例需包含多字节字符才能区分字节数与字符数'
  end

  def test_build_head_fields
    now = Time.new(2023, 10, 16, 10, 39, 1, '+08:00')
    payload = Bocd::Message.build('03020101A0008', {}, req_no: 'abc123', now: now)
    xml = payload[10..]

    assert_includes xml, '<tr_code>03020101A0008</tr_code>'
    assert_includes xml, '<req_no>abc123</req_no>'
    assert_includes xml, '<tr_acdt>20231016</tr_acdt>'
    assert_includes xml, '<tr_time>103901</tr_time>'
    assert xml.start_with?('<ap><head>')
    assert xml.end_with?('</ap>')
  end

  def test_build_converts_time_to_beijing
    # UTC 2023-10-16 18:00 = 北京时间 2023-10-17 02:00，跨日
    now = Time.utc(2023, 10, 16, 18, 0, 0)
    payload = Bocd::Message.build('03020101A0008', {}, now: now)

    assert_includes payload, '<tr_acdt>20231017</tr_acdt>'
    assert_includes payload, '<tr_time>020000</tr_time>'
  end

  def test_build_generates_unique_32_char_req_no
    first = Bocd::Message.build('X', {})[%r{<req_no>(\w+)</req_no>}, 1]
    second = Bocd::Message.build('X', {})[%r{<req_no>(\w+)</req_no>}, 1]

    assert_equal 32, first.length
    refute_equal first, second
  end

  def test_build_escapes_xml_special_chars
    payload = Bocd::Message.build('X', { summary: %(A&B <"'>) })

    assert_includes payload, '<summary>A&amp;B &lt;&quot;&apos;&gt;</summary>'
  end

  def test_build_renders_blank_values_as_self_closing
    payload = Bocd::Message.build('X', { payAsacNo: nil, postscript: '' })

    assert_includes payload, '<payAsacNo/>'
    assert_includes payload, '<postscript/>'
  end

  def test_build_renders_array_as_dto_list
    payload = Bocd::Message.build('X', { array: [{ seqNo: '1' }, { seqNo: '2' }] })

    assert_includes payload, '<array><dto><seqNo>1</seqNo></dto><dto><seqNo>2</seqNo></dto></array>'
  end

  def test_build_matches_doc_example
    # 接口文档 2.7 报文示例（缩进去除后的等价单行报文）
    now = Time.new(2022, 10, 24, 9, 15, 10, '+08:00')
    payload = Bocd::Message.build(
      '03020101A0008',
      { acctNo: '1001300000868624', currency: '01' },
      req_no: '51805a67e11f4403a06637540a637070', now: now
    )
    xml = payload[10..]

    expected = '<ap><head><tr_code>03020101A0008</tr_code>' \
               '<req_no>51805a67e11f4403a06637540a637070</req_no>' \
               '<tr_acdt>20221024</tr_acdt><tr_time>091510</tr_time></head>' \
               '<body><acctNo>1001300000868624</acctNo><currency>01</currency></body></ap>'
    assert_equal expected, xml
  end

  def test_parse_doc_example_response
    xml = <<~XML
      <ap>
        <head>
          <tr_code>03020101A0008</tr_code>
          <serial_no>022202208040000126384</serial_no>
          <req_no>51805a67e11f4403a06637540a637070</req_no>
          <tr_acdt>20221024</tr_acdt>
          <tr_time>091510</tr_time>
          <ret_code>0000</ret_code>
          <ret_info>交易成功</ret_info>
        </head>
        <body>
          <dto>
            <bookBal>989976.90</bookBal>
            <avaliableBal>989976.90</avaliableBal>
            <frzBal>0.00</frzBal>
            <ctrlBal/>
            <overdraftLimit>0.00</overdraftLimit>
            <overdraft>0.00</overdraft>
          </dto>
        </body>
      </ap>
    XML
    ap = Bocd::Message.parse(xml)

    assert_equal '0000', ap['head']['ret_code']
    assert_equal '989976.90', ap['body']['dto']['bookBal']
    assert_nil ap['body']['dto']['ctrlBal']
  end

  def test_parse_invalid_xml_raises_protocol_error
    assert_raises(Bocd::ProtocolError) { Bocd::Message.parse('not-xml<<<') }
  end

  def test_parse_missing_ap_root_raises_protocol_error
    assert_raises(Bocd::ProtocolError) { Bocd::Message.parse('<other/>') }
  end
end
