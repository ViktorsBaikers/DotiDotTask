class ScrapesController < ApplicationController

  def create
    url = scrape_params[:url]

    unless valid_url?(url)
      render json: { error: 'Invalid URL format' }, status: :bad_request
      return
    end

    result = ScraperService.new(url).extract(scrape_params[:fields] || {})
    render json: result
  rescue => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def scrape_params
    params.permit(:url, fields: {})
  end

  def valid_url?(url)
    return false if url.blank?

    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end
