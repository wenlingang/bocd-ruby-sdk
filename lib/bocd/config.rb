require 'logger'

module Bocd
  # 前置机(tbsp-interbank)交易监听端口默认 10010，见《测试环境前置软件配置》socket.port
  DEFAULT_HOST = '127.0.0.1'.freeze
  DEFAULT_PORT = 10010

  class << self
    def configure
      yield config
    end

    def config
      @config ||= Config.new
    end

    def logger
      @logger ||= if config.logger.nil?
                    defined?(Rails) && Rails.logger ? Rails.logger : Logger.new(STDOUT)
                  else
                    config.logger
                  end
    end

    def host
      config.host || DEFAULT_HOST
    end

    def port
      config.port || DEFAULT_PORT
    end

    def connect_timeout
      config.connect_timeout || 5
    end

    def read_timeout
      config.read_timeout || 30
    end

    def write_timeout
      config.write_timeout || 5
    end
  end

  class Config
    attr_accessor :host, :port,
                  :connect_timeout, :read_timeout, :write_timeout,
                  :logger
  end
end
