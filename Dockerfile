FROM ruby:4.0.9-slim AS whisper-build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --branch v1.7.6 --depth 1 https://github.com/ggml-org/whisper.cpp.git /whisper.cpp \
    && cmake -S /whisper.cpp -B /whisper.cpp/build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    && cmake --build /whisper.cpp/build --config Release --target whisper-cli -j 2

FROM ruby:4.0.9-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git libpq-dev libxml2-dev libxslt1-dev libyaml-dev pkg-config \
    nodejs ffmpeg ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=whisper-build /whisper.cpp/build/bin/whisper-cli /usr/local/bin/whisper-cli
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.4.10 --no-document && bundle install
COPY . .

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
