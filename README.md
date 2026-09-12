# Bocd SDK

成都银行（BOCD）财资管理系统银企直联 SDK for Ruby。

与农行等「开放银行 HTTPS 网关」模式不同，成都银行的银企直联通过银行下发的**前置机程序**（tbsp-interbank）接入：前置机部署在企业侧，负责与银行的安全通信（证书、加密），企业系统只需与前置机建 **TCP Socket 同步短连接**收发 XML 报文。本 SDK 实现该 Socket 协议（10 位字节长度前缀 + UTF-8 XML 报文）并封装全部业务接口。

```
企业系统(本 SDK) --TCP Socket(默认10010)--> 前置机 tbsp-interbank --专线/互联网--> 成都银行财资管理系统
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bocd-sdk'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install bocd-sdk

## 前置条件

1. 与成都银行签约银企直联，取得前置机程序 `tbsp-interbank.zip`
2. 按银行《测试环境前置软件配置》部署前置机（管理端默认端口 8081，交易监听端口 `socket.port` 默认 10010，报文编码 UTF-8）
3. 应用能通过 TCP 访问前置机的交易监听端口

## Usage

### initialize

```ruby
# config/initializers/bocd.rb

Bocd.configure do |config|
  config.host = '127.0.0.1'    # 前置机地址，默认 127.0.0.1
  config.port = 10010          # 前置机交易监听端口(socket.port)，默认 10010
  # config.connect_timeout = 5  # 建连超时（秒）
  # config.read_timeout = 30    # 读应答超时（秒），转账类交易偏慢建议 ≥ 30
  # config.write_timeout = 5    # 写请求超时（秒）
end
```

```ruby
api = Bocd::Api.new
# 或对接多台前置机时按实例覆盖：
api = Bocd::Api.new(host: '10.0.8.2', port: 10010)
```

### 账户

```ruby
# [03020101A0008] 账户余额（AIO 账户传 "AIO账号+子账户类型"）
resp = api.account.balance({ acctNo: '1001300000868624', currency: '01' })
resp.success?          # ret_code == '0000'
resp.data['dto']       # => { 'bookBal' => '989976.90', 'avaliableBal' => ..., 'frzBal' => ..., ... }

# [03020101A0007] 交易明细（分页，size 最大 200）
resp = api.account.transactions({
  acctNo: '1001300000868624', currency: '01',
  startDate: '20240101', endDate: '20240131',
  start: 1, size: 20
})
resp.total   # 总条数
resp.rows    # dto 数组（单条也归一化为数组）

# [03040304A1003] 历史余额
api.account.history_balance({ acctNo: '1001300000868624', currency: '01', dataDate: '20240101' })
```

### 转账

```ruby
# [03020104B0210] 行内转账（收款方必须是成都银行账户）
resp = api.transfer.intra_bank({
  payAcctNo: '1001300000444220', currency: '01', payAcctName: '某某公司',
  payAsacNo: nil, payAsacName: nil,             # 未签约多级账簿送空
  rcvAcctNo: '1001300000302674', rcvAcctName: '收款公司',
  amt: '2.53', resTime: nil, mobile: nil,       # resTime 有值为预约转账
  summary: '货款', postscript: nil, saveAcct: '0'
}, req_no: order_serial_no)                     # 建议用业务侧唯一流水号，便于后续查证

# [03020104B0211] 跨行转账（多 rcvBankNo/rcvBankName/urgentFlag 三个字段）
api.transfer.cross_bank({
  payAcctNo: '...', currency: '01', payAcctName: '...',
  payAsacNo: nil, payAsacName: nil,
  rcvAcctNo: '...', rcvAcctName: '...',
  rcvBankNo: '402651020006', rcvBankName: '四川省农村信用社联合社',
  amt: '16.00', urgentFlag: '1',                # 1 普通 / 2 实时
  resTime: nil, summary: '货款', postscript: nil, mobile: nil, saveAcct: nil
}, req_no: order_serial_no)

# ⚠️ 转账应答成功仅代表银行受理成功，最终结果必须用交易查证确认：
# [03020104A0239] busiStat：S/F 为终态（成功/失败），L 表示需柜台审批，其余为处理中
resp = api.transfer.verify({ reqDate: '20240101', reqSerialNo: order_serial_no })
resp.data!['busiStat']  # => 'S'

# [03020104A0229] 联行号模糊查询（跨行转账前查 rcvBankNo）
api.transfer.bank_branches({ bankNo: nil, bankName: '农村信用社', start: 1, size: 10 })
```

公转私金额超 5 万元时，`summary` 只能从文档列举的固定用途中选（奖励支付款、劳务合同支付款、借款、退款等，见接口文档 3.3/3.4 注意事项）。

### 批量转账 / 代发工资

批量类交易通过 **xlsx 文件 + 报文** 完成，文件传输不在 Socket 协议内：

1. 按银行模板（`批量转账模板.xlsx` / `代发工资模板.xlsx`）生成明细文件，代发单文件最多 3000 笔
2. 将文件放到前置机的 `config\file\data` 目录（网络共享文件夹或 FTP，由调用方自行实现）
3. 发起交易，报文只传文件名：

```ruby
# [03020104B0212] 批量转账
api.transfer.batch({
  batchNo: '20240101000000000000000000000001',  # 32 位唯一批次号
  resTime: nil, acctNo: '...', currency: '01', acctName: '...',
  asacNo: nil, asacName: nil,
  totalCount: '2', totalAmt: '4.00',            # 必须与文件内容一致
  summary: '批量付款', postscript: nil,          # 费用报销送 '1002|费用报销'
  file_name: '20240101000000000000000000000001.xlsx'
})

# [03020104B0214] 代发工资（需已签约代发，批次间隔 1 分钟）
api.payroll.pay_salary({
  batchNo: '202401010000001', acctNo: '...', currency: '01', acctName: '...',
  asacNo: nil, asacName: nil, totalCount: '5', totalAmt: '15.00',
  summary: '代发工资', file_name: '202401010000001.xlsx'
})

# [03020104A0217] 轮询批次明细结果（两者共用；tfrStat 见字典 G00281）
resp = api.transfer.batch_details({ batchNo: '...', pager: '1', start: 1, size: 10 })
resp.rows  # => [{ 'tfrApplyNo' => ..., 'tfrStat' => 'S', 'message' => ..., ... }]
```

### 电子回单

```ruby
# [00220122C0245] 交易明细电子回单：按日期区间（可选按核心流水号列表）生成 PDF
resp = api.receipt.transaction_detail({
  acctNo: '...', currency: '01',
  startDate: '20250118', endDate: '20250118',
  array: [{ seqNo: '3557945755' }]   # seqNo 取交易明细的 hostSerialNo，可省略
})
resp.data!['file_name']  # => 'tranDetail_CM022..._sign.pdf'
```

PDF 生成在前置机 `config\file\data` 目录，取回文件由调用方负责（同批量文件的共享目录/FTP 通道）。

### 分页

分页接口（交易明细、联行号、批次明细）遵循文档 2.9 算法：`start` 首页为 1，下一页 = start + 上页返回条数，`size` 全程不可变。`Api#paginate` 封装了该循环：

```ruby
rows = api.paginate(size: 100) do |start, size|
  api.account.transactions({
    acctNo: '...', currency: '01',
    startDate: '20240101', endDate: '20240131',
    start: start, size: size
  })
end
```

### Result

```ruby
resp.success?    # ret_code == '0000'
resp.ret_code    # 返回码
resp.ret_info    # 返回信息
resp.serial_no   # 银行财资系统流水号
resp.req_no      # 请求号（原样返回，交易查证用）
resp.data        # body 业务数据（Hash）
resp.data!       # 同 data，但失败时抛 Bocd::ResultError
resp.rows        # body/array/dto 归一化数组（列表类应答）
resp.total       # 分页总条数
resp.raw         # 整个 ap 节点 Hash
resp.raw_xml     # 应答原始 XML
```

### 错误处理

| 异常 | 场景 |
| --- | --- |
| `Bocd::ConnectionError` | 前置机连不上、读写超时、连接被提前关闭 |
| `Bocd::ProtocolError` | 应答长度前缀非法、XML 无法解析 |
| `Bocd::ResultError` | `data!` 且 ret_code 非 '0000'（`error.code` / `error.msg`） |

`req_no` 是幂等关键：转账类交易务必持久化后再发送，超时（`ConnectionError`）时**不要直接重发**，先用 `transfer.verify` 按原 `req_no` 查证结果。

## Apis

[查看全部接口](apis.md)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wenlingang/bocd-ruby-sdk.
