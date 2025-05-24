FROM ruby:3.2

# Install SQLite and Node (for Rails JS)
RUN apt-get update -qq && apt-get install -y build-essential libsqlite3-dev nodejs

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
