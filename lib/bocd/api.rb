require 'bocd/request'

module Bocd
  class Api
    include Helper

    api_mount :account
    api_mount :transfer
    api_mount :receipt
    api_mount :payroll

    attr_reader :host, :port, :connect_timeout, :read_timeout, :write_timeout, :options

    def initialize(options = {})
      @host = options.delete(:host) || Bocd.host
      @port = options.delete(:port) || Bocd.port
      @connect_timeout = options.delete(:connect_timeout) || Bocd.connect_timeout
      @read_timeout = options.delete(:read_timeout) || Bocd.read_timeout
      @write_timeout = options.delete(:write_timeout) || Bocd.write_timeout
      @options = options
    end

    def request
      @request ||= Bocd::Request.new(self)
    end

    def call(tr_code, body = {}, req_no: nil)
      request.call(tr_code, body, req_no: req_no)
    end

    # 按文档 2.9 分页算法全量拉取：start 首页为 1，下一页 = start + 本页返回条数，
    # 直到 start > total；size 全程不可变。block 需返回 Result，返回所有页的 rows 拼接。
    def paginate(size: 10)
      start = 1
      rows = []
      loop do
        result = yield(start, size)
        page_rows = result.rows
        rows.concat(page_rows)
        start += page_rows.size
        break if page_rows.empty? || start > result.total
      end
      rows
    end

    class << self
      def default
        @default ||= new
      end
    end
  end
end
