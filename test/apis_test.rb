require 'test_helper'

class ApisTest < Minitest::Test
  include BocdTestHelper

  # 接口方法 → 交易码（接口文档 v2.0.4 第 3 章）
  EXPECTED_TR_CODES = {
    %i[account balance] => '03020101A0008',
    %i[account transactions] => '03020101A0007',
    %i[account history_balance] => '03040304A1003',
    %i[transfer intra_bank] => '03020104B0210',
    %i[transfer cross_bank] => '03020104B0211',
    %i[transfer verify] => '03020104A0239',
    %i[transfer bank_branches] => '03020104A0229',
    %i[transfer batch] => '03020104B0212',
    %i[transfer batch_details] => '03020104A0217',
    %i[receipt transaction_detail] => '00220122C0245',
    %i[payroll pay_salary] => '03020104B0214'
  }.freeze

  def test_every_api_method_sends_expected_tr_code
    EXPECTED_TR_CODES.each do |(group, method), tr_code|
      with_frontend(echo_handler) do |server, api|
        result = api.public_send(group).public_send(method, {})

        assert result.success?, "#{group}.#{method} 应答失败"
        request = server.received
        assert_includes request, "<tr_code>#{tr_code}</tr_code>",
                        "#{group}.#{method} 应发送交易码 #{tr_code}"
      end
    end
  end

  def test_receipt_transaction_detail_sends_seq_no_array
    with_frontend(echo_handler(body: '<file_name>tranDetail_CM0222_sign.pdf</file_name>')) do |server, api|
      result = api.receipt.transaction_detail({
        acctNo: '1001300000444220',
        currency: '01',
        startDate: '20250118',
        endDate: '20250118',
        array: [{ seqNo: '3557945755' }]
      })

      assert_equal 'tranDetail_CM0222_sign.pdf', result.data!['file_name']
      request = server.received
      assert_includes request, '<array><dto><seqNo>3557945755</seqNo></dto></array>'
    end
  end

  def test_transfer_verify_returns_busi_stat
    with_frontend(echo_handler(body: '<jnlMsg>交易成功</jnlMsg><busiStat>S</busiStat>')) do |server, api|
      result = api.transfer.verify({ reqDate: '20231016', reqSerialNo: '3ea70fe71ec547a9a930fff8d1125b08' })

      assert_equal 'S', result.data!['busiStat']
      assert_includes server.received, '<reqSerialNo>3ea70fe71ec547a9a930fff8d1125b08</reqSerialNo>'
    end
  end

  def test_api_default_singleton_and_config_defaults
    assert_equal Bocd::Api.default.object_id, Bocd::Api.default.object_id
    api = Bocd::Api.new
    assert_equal '127.0.0.1', api.host
    assert_equal 10_010, api.port
  end
end
