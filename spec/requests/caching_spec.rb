require 'rails_helper'

RSpec.describe 'HTML Caching Behavior', type: :request do
  before do
    stub_request(:get, /cf_bypass/)
      .to_return(status: 200, body: '<html><body><div class="a">A</div></body></html>')
  end

  it 'avoids duplicate fetches for concurrent requests' do
    threads = []
    5.times do
      threads << Thread.new do
        get '/data', params: { url: 'http://example.com', fields: { a: '.a' } }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }
      end
    end
    threads.each(&:join)

    # Should have been called only once
    stub_request(:get, "http://cf_bypass:8000/html?url=http://example.com")
      .to_return(status: 200, body: '<html><body><div class="a">A</div></body></html>')
  end
end
