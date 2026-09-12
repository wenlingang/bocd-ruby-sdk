require 'bocd/version'
require 'active_support/all'
require 'bocd/config'
require 'bocd/helper'
require 'bocd/message'
require 'bocd/connection'
require 'bocd/request'

lib_path = "#{File.dirname(__FILE__)}/bocd"
Dir["#{lib_path}/apis/**/*.rb"].each { |path| require path }

require 'bocd/api'

module Bocd
  class Error < StandardError; end
  # 连接前置机失败/读写超时/连接被关闭
  class ConnectionError < Error; end
  # 长度前缀非法或应答 XML 无法解析
  class ProtocolError < Error; end

  # data! 且 ret_code 非 '0000'
  class ResultError < Error
    attr_reader :code, :msg

    def initialize(code, msg = '')
      @code = code
      @msg = msg
      super "(#{code}) #{msg}"
    end
  end
end
