FROM madnificent/elixir-server:1.6.7

COPY . /app

RUN sh /setup.sh
