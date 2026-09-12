require 'test_helper'

class RequestTest < Minitest::Test
  include BocdTestHelper

  DOC_BALANCE_BODY = '<dto><bookBal>989976.90</bookBal><avaliableBal>989976.90</avaliableBal>' \
                     '<frzBal>0.00</frzBal><ctrlBal/><overdraftLimit>0.00</overdraftLimit>' \
                     '<overdraft>0.00</overdraft></dto>'.freeze

  def test_balance_end_to_end_with_doc_example
    with_frontend(echo_handler(body: DOC_BALANCE_BODY)) do |server, api|
      result = api.account.balance({ acctNo: '1001300000868624', currency: '01' })

      assert result.success?
      refute result.failure?
      assert_equal '0000', result.ret_code
      assert_equal '交易成功', result.ret_info
      assert_equal '022202409010000066239', result.serial_no
      assert_equal '989976.90', result.data['dto']['bookBal']
      assert_equal '0.00', result.data['dto']['frzBal']
      assert_nil result.data['dto']['ctrlBal']

      request = server.received
      assert_includes request, '<tr_code>03020101A0008</tr_code>'
      assert_includes request, '<acctNo>1001300000868624</acctNo>'
      assert_includes request, '<currency>01</currency>'
    end
  end

  def test_custom_req_no_is_sent_and_echoed
    with_frontend(echo_handler) do |server, api|
      result = api.account.balance({ acctNo: 'x' }, req_no: 'my-erp-serial-001')

      assert_equal 'my-erp-serial-001', result.req_no
      assert_includes server.received, '<req_no>my-erp-serial-001</req_no>'
    end
  end

  def test_failure_result_and_data_bang
    with_frontend(echo_handler(ret_code: 'E123', ret_info: '账户不存在')) do |_server, api|
      result = api.account.balance({ acctNo: 'bad' })

      refute result.success?
      assert result.failure?
      error = assert_raises(Bocd::ResultError) { result.data! }
      assert_equal 'E123', error.code
      assert_equal '账户不存在', error.msg
      assert_includes error.message, 'E123'
    end
  end

  def test_rows_normalizes_single_dto_to_array
    body = '<total>1</total><array><dto><bankNo>0001</bankNo></dto></array>'
    with_frontend(echo_handler(body: body)) do |_server, api|
      result = api.transfer.bank_branches({ bankName: '成都' })

      assert_equal 1, result.total
      assert_equal [{ 'bankNo' => '0001' }], result.rows
    end
  end

  def test_rows_with_multiple_dtos
    body = '<total>381</total><array>' \
           '<dto><hostSerialNo>1</hostSerialNo><amt>10.02</amt></dto>' \
           '<dto><hostSerialNo>2</hostSerialNo><amt>3.00</amt></dto>' \
           '</array>'
    with_frontend(echo_handler(body: body)) do |_server, api|
      result = api.account.transactions({ acctNo: 'x', start: 1, size: 20 })

      assert_equal 381, result.total
      assert_equal %w[1 2], result.rows.map { |row| row['hostSerialNo'] }
    end
  end

  def test_rows_empty_when_body_has_no_array
    with_frontend(echo_handler) do |_server, api|
      result = api.transfer.batch({ batchNo: 'b1' })

      assert_equal [], result.rows
      assert result.success?
    end
  end

  def test_paginate_fetches_all_pages_per_doc_algorithm
    starts = []
    all = [
      { 'seq' => '1' }, { 'seq' => '2' }, { 'seq' => '3' }, { 'seq' => '4' }, { 'seq' => '5' }
    ]
    body = proc do |request_xml|
      start = extract(request_xml, 'start').to_i
      size = extract(request_xml, 'size').to_i
      starts << start
      page = all[start - 1, size] || []
      dtos = page.map { |row| "<dto><seq>#{row['seq']}</seq></dto>" }.join
      "<total>#{all.size}</total><array>#{dtos}</array>"
    end

    with_frontend(echo_handler(body: body)) do |_server, api|
      rows = api.paginate(size: 2) do |start, size|
        api.account.transactions({ acctNo: 'x', start: start, size: size })
      end

      assert_equal %w[1 2 3 4 5], rows.map { |row| row['seq'] }
      assert_equal [1, 3, 5], starts
    end
  end

  def test_paginate_stops_on_empty_page
    with_frontend(echo_handler(body: '<total>10</total><array></array>')) do |_server, api|
      rows = api.paginate(size: 5) do |start, size|
        api.account.transactions({ acctNo: 'x', start: start, size: size })
      end

      assert_equal [], rows
    end
  end
end
