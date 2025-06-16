require 'rails_helper'

RSpec.describe ScraperService, type: :service do
  let(:url) { 'http://example.com' }
  let(:html) do
    '<html><body>' \
      '<div class="one">A</div>' \
      '<span class="two">B</span>' \
      '</body></html>'
  end

  describe '#extract' do
    context 'basic extraction' do
      before do
        # Avoid real HTTP
        allow_any_instance_of(ScraperService)
          .to receive(:fetch_html)
                .and_return(html)
      end

      it 'extracts multiple fields correctly' do
        result = ScraperService.new(url).extract({ 'one' => '.one', 'two' => '.two' })
        expect(result['one']).to eq('A')
        expect(result['two']).to eq('B')
      end

      it 'performs extraction in parallel' do
        # Simulate slow parsing
        allow_any_instance_of(ScraperService).to receive(:parse_field) do |_, _, _|
          sleep 0.1
          'X'
        end

        time = Benchmark.realtime do
          ScraperService.new(url).extract({ a: '.one', b: '.two', c: '.one', d: '.two' })
        end

        # With a 4‐thread pool, total should be under 0.25s
        expect(time).to be < 0.25
      end
    end

    context 'caching HTML by URL' do
      before do
        # Stub the real bypass endpoint for this context only
        stub_request(
          :get,
          "#{described_class::CF_BYPASS}?url=#{url}"
        ).to_return(status: 200, body: html)
      end

      it 'only fetches HTML once when extracting twice' do
        service = ScraperService.new(url)

        # First call hits HTTParty.get
        service.extract('one' => '.one')
        # Second call should use cache
        service.extract('two' => '.two')

        expect(
          a_request(:get, "#{described_class::CF_BYPASS}?url=#{url}")
        ).to have_been_made.once
      end
    end
  end
end
