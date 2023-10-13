FROM madnificent/elixir-server:1.13.0

COPY . /app

RUN sh /setup.sh
