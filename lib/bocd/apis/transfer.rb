module Bocd
  module Apis
    module Transfer
      # [03020104B0210] 行内转账（收款账号必须是成都银行账户）
      # body: payAcctNo, currency, payAcctName, payAsacNo, payAsacName,
      #       rcvAcctNo, rcvAcctName, amt, resTime(有值为预约转账), mobile,
      #       summary(必填；公转私超5万摘要须用文档列举的固定选项), postscript, saveAcct
      # 返回成功仅表示受理成功，转账结果以 verify(03020104A0239) 的 busiStat 为准
      def intra_bank(body = {}, req_no: nil)
        call '03020104B0210', body, req_no: req_no
      end

      # [03020104B0211] 跨行转账
      # 在行内转账字段基础上增加: rcvBankNo/rcvBankName(联行号与行名，可由 bank_branches 查询),
      #       urgentFlag(加急标识 G00052: 1普通/2实时)
      # 返回成功仅表示受理成功，转账结果以 verify(03020104A0239) 的 busiStat 为准
      def cross_bank(body = {}, req_no: nil)
        call '03020104B0211', body, req_no: req_no
      end

      # [03020104A0239] 交易查证（查询行内/跨行转账结果）
      # body: reqDate(原转账请求头 tr_acdt), reqSerialNo(原转账请求 req_no)
      # 应答: jnlMsg(原交易信息), busiStat(G00281 业务状态，S/F 为终态，L 需柜台审批)
      def verify(body = {}, req_no: nil)
        call '03020104A0239', body, req_no: req_no
      end

      # [03020104A0229] 查询联行号列表（分页，行号/行名模糊查询）
      # body: bankNo, bankName, start(默认1), size(默认10)
      # 应答 dto: bankNo/bankName/bankType/bankShortName/cityCode/clearingBankNo
      def bank_branches(body = {}, req_no: nil)
        call '03020104A0229', body, req_no: req_no
      end

      # [03020104B0212] 批量转账（xlsx 文件需事先放到前置机 config\file\data 目录）
      # body: batchNo(32位唯一批次号), resTime, acctNo, currency, acctName, asacNo, asacName,
      #       totalCount, totalAmt(与文件内容一致), summary, postscript(费用报销送"1002|费用报销"),
      #       file_name(文件名)
      # 批次结果用 batch_details(03020104A0217) 查询
      def batch(body = {}, req_no: nil)
        call '03020104B0212', body, req_no: req_no
      end

      # [03020104A0217] 转账批次-明细查询（分页；批量转账与代发工资共用）
      # body: batchNo, pager(1 代表分页), start, size(默认10)
      # 应答 dto: tfrApplyNo, tfrStat(G00281), message, trDate/trTime, 账户与对方信息, amt/feeAmt 等
      def batch_details(body = {}, req_no: nil)
        call '03020104A0217', body, req_no: req_no
      end
    end
  end
end
