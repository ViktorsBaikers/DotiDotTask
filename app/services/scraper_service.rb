class ScraperService
  CF_BYPASS = ENV.fetch('CF_BYPASS_URL', 'http://cf_bypass:8000/html')
  CACHE_TTL = 1.hour
  POOL_SIZE = (ENV['THREAD_POOL_SIZE'] || Concurrent.processor_count).to_i
  MAX_RESPONSE = (ENV['MAX_RESPONSE_SIZE'] || 5 * 1024 * 1024).to_i

  def initialize(url)
    @url = url
    @cache = Rails.cache
  end

  def extract(fields)
    html = fetch_html
    raise_if_too_large(html)

    document = Nokogiri::HTML(html)

    result = Concurrent::Hash.new
    pool = Concurrent::FixedThreadPool.new(POOL_SIZE)

    fields.each do |name, selector_or_list|
      pool.post do
        result[name] = parse_field(document, name, selector_or_list)
      end
    end

    pool.shutdown
    pool.wait_for_termination

    result
  end

  private

  def raise_if_too_large(html)
    if html.bytesize > MAX_RESPONSE
      raise "Payload too large (#{(html.bytesize / 1024.0).round(1)} kB > #{MAX_RESPONSE} bytes)"
    end
  end

  def html_cache_key
    "data:html:#{Digest::MD5.hexdigest(@url)}"
  end

  def fetch_html
    key = html_cache_key
    return @cache.read(key) if @cache.exist?(key)

    response = begin
                 HTTParty.get(CF_BYPASS, query: { url: @url })
               rescue StandardError => e
                 raise "Fetch error: #{e.message}"
               end

    unless response.success?
      raise "Fetch error: HTTP #{response.code}"
    end

    @cache.write(key, response.body, expires_in: CACHE_TTL)
    response.body
  end

  def parse_field(doc, name, sel)
    if name.to_s == 'meta'
      sel.each_with_object({}) do |meta_name, memo|
        memo[meta_name] = doc.at("meta[name='#{meta_name}']")&.[]('content')
      end
    else
      doc.css(sel).map(&:text).first&.strip
    end
  end
end
