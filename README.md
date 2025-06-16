# Rails Scraper API

Rails 7 API application that can fetch arbitrary CSS-selected fields (and meta tags) from any  public webpage.
those behind Cloudflare Turnstile — using an open-source bypass proxy, Redis caching and a parallel extraction thread
pool.
maximum speed.

---

## Table of Contents

- [Architecture & Flow](#architecture--flow)
- [Features & Strengths](#features--strengths)
- [Known Weaknesses & Improvements](#known-weaknesses--improvements)
- [Getting Started](#getting-started)
    - [Environment Variables](#environment-variables)
    - [Build & Run](#build--run)
- [Usage](#usage)
    - [Example Request](#example-request)
- [Running the Test Suite](#running-the-test-suite)
    - [Benchmark Output](#benchmark-output)

---

## Architecture & Flow

1. **Rails API**
    - Single `/data` endpoint (JSON POST) in `ScrapesController`
    - Inherits from `ActionController::API` for minimal footprint
2. **ScraperService**
    - Fetches raw HTML via an HTTP call to a Cloudflare bypass proxy
    - Payload check: Rejects responses larger than MAX_RESPONSE_SIZE (default: 5 MB)
    - Caches the raw HTML in Redis under a URL-based key (MD5(url)) with a TTL of 1 hour
    - Parses out requested fields **in parallel** using a `Concurrent::FixedThreadPool` (default size = number of CPU
      cores)
    - Supports both CSS selectors and meta-tag lookup
3. **Cloudflare Turnstile Bypass**
    - Rails does **not** directly solve captchas; instead it proxies to a local bypass container
    - Bypass proxy (ghcr.io/sarperavci/cloudflarebypassforscraping) runs on port 8000
    - Initial fetch is **noticeably slower** (by hundreds of milliseconds) because Turnstile tokens are obtained and
      validated
    - Any subsequent hits within the cache TTL are immediate
4. **Caching**
    - Redis is configured as Rails’s `cache_store` in **development**, **test**, and **production**
    - Key: `scrape:html:<md5(url)>`
    - TTL: `CACHE_TTL` (1 hour by default)
5. **Parallelism & Speed**
    - Field extraction uses a thread pool sized according to either the value of the environment variable
      THREAD_POOL_SIZE or the number of CPUs.
    - Multi-field throughput confirmed by benchmarking with benchmark-ips.

---

## Features & Strengths

- **Instant, synchronous responses** (no background jobs)
- **URL-only caching**: repeatedly scraping the same page will never bypass the proxy until the TTL expires
- **Configurable thread-pool size** (`THREAD_POOL_SIZE`) for tuning parallelism
- **Max-response-size guard** (`MAX_RESPONSE_SIZE`) this prevents memory overload on very large pages
- **Meta-tag support** and arbitrary CSS selectors
- **Cloudflare Turnstile** bypass via a self-hosted proxy — no paid services or Selenium required
- **Parallel extraction** to reduce latency for multi-field requests.
- **Comprehensive RSpec suite** covering:
    - Service unit tests
    - Request specs with WebMock stubs
    - Concurrency & caching behavior
    - Benchmark-IPS performance tests

---

## Known Weaknesses & Improvements

| Area                   | Current                         | Concerns & Possible Improvements                                          |
|------------------------|---------------------------------|---------------------------------------------------------------------------|
| **Initial Latency**    | ~300–800 ms on first fetch      | It is acceptable for many use cases. Consider using a warm-up or prefetch |
| **Error Handling**     | Raises generic 400 on any error | Distinguish between network, parsing and selector errors                  |
| **Retries**            | None                            | Implement retry and backoff mechanisms for transient network failures.    |
| **Rate Limiting**      | None                            | Implement per-URL or per-IP rate limiting to prevent abuse.               |
| **Cache Invalidation** | TTL only                        | Support manual invalidation or a purge triggered by a webhook.            |
| **Logging & Metrics**  | Minimal                         | Integrate structured logging (Lograge) and metrics (Prometheus)           |
| **Large Pages**        | Entire HTML in memory           | Stream parse or set tighter `MAX_RESPONSE_SIZE`                           |

---

## Getting Started

### Environment Variables

- Docker & Docker Compose
- A local `.env` with the following keys (example values):

  ```dotenv
  RAILS_ENV=development
  DB_HOST=db
  DB_USER=postgres
  DB_PASSWORD=postgres
  DATABASE_URL=postgresql://postgres:postgres@db:5432
  REDIS_URL=redis://redis:6379/1
  THREAD_POOL_SIZE=4
  RAILS_MAX_THREADS=5
  MAX_RESPONSE_SIZE=5242880  # 5*1024*1024 bytes
  CF_BYPASS_URL=http://cf_bypass:8000/html

### Build & Run

- Database setup runs automatically on web start (rails db:create db:migrate)
- Build & start all services:

  ```bash
  docker compose build
  docker compose up -d

## Usage

Send a JSON POST to /data with:

- url: target page URL
- fields:
    - key: your field name
    - value: either a CSS selector string or an array of meta tag names

### Example Request

- `.price-box__price` does not exist on the page, so we price from `.price-box__primary-price__value`
- Send a POST request to `localhost:3000/data` with the following JSON body:

  ```bash
  curl -X POST localhost:3000/data \
    -H 'Content-Type: application/json' \
    -d '{
      "url":"https://www.alza.cz/aeg-7000-prosteam-lfr73964cc-d7635493.htm",
      "fields":{
        "price":".price-box__primary-price__value",
        "rating_value":".ratingValue",
        "rating_count":".ratingCount",
        "meta":["keywords","twitter:image"]
      }
    }'

### Response

- A JSON response with the requested fields and meta tags:

  ```json
  {
   "price": "18290,-",
   "rating_value": "4,9",
   "rating_count": "7 hodnocení",
   "meta": {
     "keywords": "Parní pračka AEG…",
     "twitter:image": "https://image.alza.cz/…"
   }
  }

## Running the Test Suite

- All specs (unit, request, concurrency, benchmark) live under spec/. From project root:

  ```bash
  docker compose run web rspec

- You should see:

  ```text
  ruby 3.2.8 (2025-03-26 revision 13f495dc2c) [aarch64-linux]
  Warming up --------------------------------------
  extract fields   463.000 i/100ms
  Calculating -------------------------------------
  extract fields      4.103k (±16.8%) i/s  (243.74 μs/i) -8.334k in   2.105315s

  10 examples, 0 failures

### Benchmark Output

- You should see:

  ```text
  Warming up --------------------------------------
  extract fields   463.000 i/100ms
  Calculating -------------------------------------
  extract fields      4.103k (±16.8%) i/s  (243.74 μs/i) -8.334k in   2.105315s
