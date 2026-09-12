module Bocd
  module Apis
    module Payroll
      # [03020104B0214] 代发工资（需已签约代发；xlsx 文件需事先放到前置机 config\file\data 目录）
      # body: batchNo(C15 唯一批次号), acctNo, currency(目前只支持01), acctName, asacNo, asacName,
      #       totalCount/totalAmt(与文件内容一致), summary, file_name
      # 单文件最多 3000 笔，批次间隔 1 分钟；批次结果用 transfer.batch_details(03020104A0217) 查询
      def pay_salary(body = {}, req_no: nil)
        call '03020104B0214', body, req_no: req_no
      end
    end
  end
end
