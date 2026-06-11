FROM madnificent/elixir-server:1.14.0

ENV IEX_NAME=mu_identifier@ip
ENV IEX_COOKIE=mu-identifier

COPY . /app

RUN sh /setup.sh
