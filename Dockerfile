FROM madnificent/elixir-server:1.12.0

COPY . /app

RUN sh /setup.sh
