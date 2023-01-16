FROM madnificent/elixir-server:1.11.0

COPY . /app

RUN sh /setup.sh
