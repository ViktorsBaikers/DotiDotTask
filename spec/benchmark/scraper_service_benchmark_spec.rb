require 'rails_helper'

RSpec.describe 'ScraperService benchmark', type: :benchmark do
  let(:url) { 'http://example.com' }
  let(:html) do
    '<html><body>' +
      '<div class="one">A</div>' +
      '<span class="two">B</span>' +
      '</body></html>'
  end

  before do
    allow_any_instance_of(ScraperService).to receive(:fetch_html).and_return(html)
  end

  it 'benchmarks extract performance' do
    service = ScraperService.new(url)
    Benchmark.ips do |x|
      x.config(time: 2, warmup: 1)
      x.report('extract fields') do
        service.extract({ 'one' => '.one', 'two' => '.two', 'three' => '.one', 'four' => '.two' })
      end
      x.compare!
    end
  end
end
