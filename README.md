# SegmentAPI

Basic HTTP wrapper for the Segment service.

## Installation

Package can be installed by adding `segment_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:segment_api, github: "pixelunion/elixir-segment-api", tag: "v0.2.3"}
  ]
end
```

Add the following configuration to your config.ex

```elixir
config :segment_api, :api_key, "<your encoded basic auth keys>"
```

Use like

```elixir
app_slug = "USO"
shopify_domain = "example.myshopify.com"
type = :customer_data_request

SegmentAPI.track(
  SegmentAPI.event(app_slug, type),
  shopify_domain,
  %{data: %{foo: "bar"}},
  %{integrations: %{All: true, Salesforce: false}}
)
```

## Transport and responses

Requests use Req and return `{:ok, %Req.Response{status: status, body: body}}`
for HTTP responses, including non-success statuses. Response bodies remain raw
strings. Transport failures return `{:error, exception}`. Callers migrating from
HTTPoison must match `Req.Response.status` instead of `HTTPoison.Response.status_code`.
The inherited HTTPoison request functions are no longer exposed.

Event POST requests do not automatically retry or follow redirects, preventing
implicit event replays. Receive and connection timeouts are five and eight
seconds, respectively. Req requires Elixir 1.15 or later.

The `:api_key` setting is the raw Segment write key; the client encodes Basic
authentication itself. The optional `:endpoint` setting overrides the default
`https://api.segment.io/v1`, for example for a local HTTP test server.
