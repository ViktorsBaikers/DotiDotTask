require 'rails_helper'

describe ScraperService, type: :service do
  let(:url) { 'http://bad.example.com' }

  before do
    # Simulate network error
    allow(HTTParty).to receive(:get).and_raise(Net::OpenTimeout)
  end

  it 'raises meaningful error on fetch failure' do
    expect { ScraperService.new(url).extract('x' => '.x') }
      .to raise_error(/Fetch error/)
  end
end
