FROM ruby:3.2

env DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs yarn

WORKDIR /app

COPY Gemfile* ./
RUN bundle install --jobs 4

COPY . .

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
