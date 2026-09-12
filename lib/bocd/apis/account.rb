module Bocd
  module Apis
    module Account
      # [03020101A0008] 账户余额信息查询
      # body: acctNo(账号，AIO 账户传"AIO账号+子账户类型"), currency(币种 G00001，01 人民币)
      # 应答 dto: bookBal/avaliableBal/frzBal/ctrlBal/overdraftLimit/overdraft
      def balance(body = {}, req_no: nil)
        call '03020101A0008', body, req_no: req_no
      end

      # [03020101A0007] 账户交易明细查询（分页）
      # body: acctNo, currency, startDate/endDate(yyyyMMdd), start(默认1), size(默认10，最大200)
      # hostSerialNo(核心流水号) + trDate 可确定一笔流水唯一；付款关联用 summary 字段
      def transactions(body = {}, req_no: nil)
        call '03020101A0007', body, req_no: req_no
      end

      # [03040304A1003] 账户历史余额信息查询
      # body: acctNo, currency, dataDate(yyyyMMdd)
      def history_balance(body = {}, req_no: nil)
        call '03040304A1003', body, req_no: req_no
      end
    end
  end
end
