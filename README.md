## Proxy

A HTTP proxy skeleton written in Elixir with Plug (Adapter) + Cowboy (Server) + Hackney (Client).

Not complete in any way (no proxy headers set) but feel free to use it as starting point.

Requires Elixir v1.0.

### Development

To run it in development:

    mix deps.get
    mix serve

### Production

To run it in production:

    mix deps.get
    MIX_ENV=prod mix do compile, compile.protocols
    MIX_ENV=prod elixir -pa _build/prod/consolidated -S mix serve

### License

MIT-LICENSE
