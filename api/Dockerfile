FROM ruby:3.3-alpine

RUN apk add --no-cache build-base postgresql-dev
WORKDIR /app

COPY api/Gemfile ./
RUN bundle install

COPY api/ .
EXPOSE 4567

CMD ["bundle", "exec", "puma", "-C", "puma.rb"]
