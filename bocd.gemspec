# frozen_string_literal: true

require_relative 'lib/bocd/version'

Gem::Specification.new do |spec|
  spec.name          = 'bocd-sdk'
  spec.version       = Bocd::VERSION
  spec.authors       = ['wenlingang']
  spec.email         = ['wen.sprint@gmail.com']

  spec.summary       = 'BOCD(成都银行) 财资管理系统银企直联 SDK for ruby'
  spec.description   = '成都银行财资管理系统银企直联接口 SDK，通过银行前置机(tbsp-interbank)的 TCP Socket 通道收发 XML 报文'
  spec.homepage      = 'https://github.com/wenlingang/bocd-ruby-sdk'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org/'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/wenlingang/bocd-ruby-sdk'
  spec.metadata['changelog_uri'] = 'https://github.com/wenlingang/bocd-ruby-sdk'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features|docs)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 3.2.0'
  # Hash.from_xml 的默认解析后端；Ruby 3.4 起 rexml 不再随解释器捆绑，需显式声明
  spec.add_dependency 'rexml'

  spec.add_development_dependency 'bundler', '>= 1.13'
  spec.add_development_dependency 'minitest', '~> 5.10'
  spec.add_development_dependency 'rake', '~> 13.0'
end
