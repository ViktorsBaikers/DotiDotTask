require 'rails_helper'

describe ScrapesController, type: :controller do
  let(:url) { 'http://example.com' }

  describe 'GET #create' do
    before do
      allow_any_instance_of(ScraperService).to receive(:extract).and_return({ 'val' => '123' })
    end

    it 'returns ok and JSON body' do
      get :create, params: { url: url, fields: { val: '.val' } }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['val']).to eq('123')
    end

    it 'returns error on exception' do
      allow_any_instance_of(ScraperService).to receive(:extract).and_raise('fail')
      get :create, params: { url: url, fields: {} }
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to eq('fail')
    end

    it 'returns error on invalid URL' do
      allow_any_instance_of(ScraperService).to receive(:extract).and_raise('Invalid URL format')
      get :create, params: { url: 'invalid', fields: {} }
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to eq('Invalid URL format')
    end
  end
end
