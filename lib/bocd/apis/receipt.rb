module Bocd
  module Apis
    module Receipt
      # [00220122C0245] 交易明细电子回单下载
      # body: acctNo, currency, startDate/endDate(yyyyMMdd),
      #       array: [{ seqNo: 核心流水号(交易明细的 hostSerialNo) }, ...]（可选，不传则按日期区间）
      # 应答: file_name(PDF 文件名)，文件生成在前置机 config\file\data 目录，取回由调用方负责
      def transaction_detail(body = {}, req_no: nil)
        call '00220122C0245', body, req_no: req_no
      end
    end
  end
end
