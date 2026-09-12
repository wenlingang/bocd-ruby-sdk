# Apis

对应《成都银行财资管理系统--银企直联接口文档 v2.0.4》第 3 章。

## account（账户）

| 交易码 | 接口 | 方法 |
| --- | --- | --- |
| 03020101A0008 | 账户余额信息查询 | `api.account.balance` |
| 03020101A0007 | 账户交易明细查询（分页） | `api.account.transactions` |
| 03040304A1003 | 账户历史余额信息查询 | `api.account.history_balance` |

## transfer（转账）

| 交易码 | 接口 | 方法 |
| --- | --- | --- |
| 03020104B0210 | 行内转账 | `api.transfer.intra_bank` |
| 03020104B0211 | 跨行转账 | `api.transfer.cross_bank` |
| 03020104A0239 | 交易查证 | `api.transfer.verify` |
| 03020104A0229 | 查询联行号列表（分页） | `api.transfer.bank_branches` |
| 03020104B0212 | 批量转账 | `api.transfer.batch` |
| 03020104A0217 | 转账批次-明细查询（分页） | `api.transfer.batch_details` |

## receipt（电子回单）

| 交易码 | 接口 | 方法 |
| --- | --- | --- |
| 00220122C0245 | 交易明细电子回单下载 | `api.receipt.transaction_detail` |

## payroll（代发）

| 交易码 | 接口 | 方法 |
| --- | --- | --- |
| 03020104B0214 | 代发工资 | `api.payroll.pay_salary` |

## 未实现

- `03020101A0095` AIO 账户余额查询、`03020101A0096` AIO 账户交易明细查询：文档 v2.0.4 已标注**作废**，余额/明细接口（A0008/A0007）传 "AIO账号+子账户类型" 即可查询 AIO 账户
- 多级账簿子账簿系列（新增/更新/删除/余额查询等）：文档中无交易码、章节为空占位；其中 `03040102A0105` 账簿交易明细、`03040105B0401` 账簿间转账的示例报文使用另一套扩展报文头（org_code/cms_corp_no/user_no 等，疑似旧直连通道遗留），与前置机标准报文头不一致，待与银行确认后再补充
