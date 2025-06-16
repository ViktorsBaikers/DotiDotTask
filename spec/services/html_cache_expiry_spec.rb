require 'rails_helper'

describe 'HTML cache expiry', type: :service do
  let(:url) { 'http://example.com' }
  let(:html1) { '<html><body><div class="x">1</div></body></html>' }
  let(:html2) { '<html><body><div class="x">2</div></body></html>' }

  it 're-fetches after cache expiry' do
    svc = ScraperService.new(url)
    # Fresh fetch
    allow_any_instance_of(ScraperService).to receive(:fetch_html).and_return(html1)
    result1 = svc.extract('x' => '.x')
    expect(result1['x']).to eq('1')

    # Expire cache
    Rails.cache.clear

    # Second fetch
    allow_any_instance_of(ScraperService).to receive(:fetch_html).and_return(html2)
    result2 = svc.extract('x' => '.x')
    expect(result2['x']).to eq('2')
  end
end
