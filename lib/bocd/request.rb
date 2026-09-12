module Bocd
  class Request
    attr_reader :api

    def initialize(api)
      @api = api
    end

    def call(tr_code, body = {}, req_no: nil)
      payload = Message.build(tr_code, body, req_no: req_no)
      Bocd.logger.debug { "[bocd] >> #{payload}" }

      response_xml = connection.call(payload)
      Bocd.logger.debug { "[bocd] << #{response_xml}" }

      Result.new(Message.parse(response_xml), response_xml)
    end

    private

    def connection
      @connection ||= Connection.new(
        host: api.host, port: api.port,
        connect_timeout: api.connect_timeout,
        read_timeout: api.read_timeout,
        write_timeout: api.write_timeout
      )
    end
  end

  class Result
    attr_reader :raw, :raw_xml, :head, :data

    def initialize(ap, raw_xml = nil)
      @raw = ap || {}
      @raw_xml = raw_xml
      @head = @raw['head'] || {}
      @data = @raw['body'] || {}
    end

    def tr_code
      head['tr_code']
    end

    def req_no
      head['req_no']
    end

    # 银行财资管理系统返回的流水号
    def serial_no
      head['serial_no']
    end

    def ret_code
      head['ret_code'].to_s
    end

    def ret_info
      head['ret_info'].to_s
    end

    def success?
      ret_code == '0000'
    end

    def failure?
      !success?
    end

    def data!
      raise ResultError.new(ret_code, ret_info) unless success?

      data
    end

    # 分页查询应答的总条数（body/total）
    def total
      data['total'].to_i
    end

    # 列表类应答 body/array/dto 归一化为 Hash 数组（单条时 Hash.from_xml 不产生数组）
    def rows
      array = data['array']
      return [] if array.nil? || !array.is_a?(Hash)

      Array.wrap(array['dto']).compact
    end
  end
end
