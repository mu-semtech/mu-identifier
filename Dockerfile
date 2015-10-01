FROM madnificent/elixir-server:latest

ADD . /app

RUN sh /setup.sh
