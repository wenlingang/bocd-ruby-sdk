require 'securerandom'

module Bocd
  # 报文规范（接口文档 2.3/2.6）：
  #   请求报文 = 10 位交易报文字节长度（不足前补零） + 交易报文
  #   交易报文 = <ap><head>公共报文头</head><body>业务体</body></ap>，UTF-8，无 XML 声明
  module Message
    XML_ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&apos;' }.freeze

    class << self
      # 构建完整请求（含长度前缀）。req_no 不传时自动生成 32 位唯一请求号（同文档示例格式）
      def build(tr_code, body = {}, req_no: nil, now: nil)
        # 银行按北京时间校验交易日期/时间，进程时区非 +08:00 时 Time.now 直接取会偏差
        now = (now || Time.now).getlocal('+08:00')
        head = {
          'tr_code' => tr_code,
          'req_no' => req_no || generate_req_no,
          'tr_acdt' => now.strftime('%Y%m%d'),
          'tr_time' => now.strftime('%H%M%S')
        }
        xml = "<ap><head>#{to_xml(head)}</head><body>#{to_xml(body)}</body></ap>"
        # 长度按字节计（中文 UTF-8 占 3 字节），不是字符数
        format('%010d', xml.bytesize) + xml
      end

      def generate_req_no
        SecureRandom.uuid.delete('-')
      end

      # 解析应答交易报文（不含长度前缀）→ 整个 ap 节点的 Hash
      def parse(xml)
        ap = begin
          Hash.from_xml(xml)['ap']
        rescue StandardError => e
          raise ProtocolError, "应答报文 XML 解析失败: #{e.message}"
        end
        raise ProtocolError, "应答报文缺少 ap 根节点: #{xml.to_s[0, 200]}" unless ap.is_a?(Hash)

        ap
      end

      private

      # Hash → XML 节点串。约定：
      #   值为 Array（元素为 Hash）时展开为 <key><dto>...</dto><dto>...</dto></key>
      #   值为 Hash 时递归；nil/空串输出自闭合空节点（C 类条件字段要求出现但可为空）
      def to_xml(hash)
        hash.map do |key, value|
          case value
          when Array
            inner = value.map { |item| "<dto>#{to_xml(item)}</dto>" }.join
            "<#{key}>#{inner}</#{key}>"
          when Hash
            "<#{key}>#{to_xml(value)}</#{key}>"
          when nil, ''
            "<#{key}/>"
          else
            "<#{key}>#{escape(value.to_s)}</#{key}>"
          end
        end.join
      end

      def escape(text)
        text.gsub(/[&<>"']/) { |char| XML_ESCAPES[char] }
      end
    end
  end
end
