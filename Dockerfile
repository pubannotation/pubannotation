FROM ruby:4.0.5-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git libpq-dev libxml2-dev libxslt1-dev libyaml-dev pkg-config \
    nodejs ffmpeg ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.4.10 --no-document && bundle install
COPY . .

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
