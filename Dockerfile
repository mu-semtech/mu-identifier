FROM madnificent/elixir-server:1.9

COPY . /app

RUN sh /setup.sh
