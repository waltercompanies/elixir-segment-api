defmodule SegmentAPI do
  @moduledoc """
  Segment API
  """
  use HTTPoison.Base
  require Logger

  @endpoint "https://api.segment.io/v1"
  # As per docs https://segment.com/docs/sources/server/http/
  @app_version Keyword.get(Mix.Project.config(), :version)

  @doc """
  Tracks an event
  """
  def track(event, properties, identity, options \\ %{}) do
    body =
      %{
        event: event,
        properties: strip_context(properties),
        context: context(properties),
        integrations: Map.get(options, :integrations)
      }
      |> identity_params(identity)

    body
    |> remove_nil_values()
    |> Jason.encode()
    |> post_or_return_error("track")
  end

  @doc """
  Tracks a page view
  """
  def page(page, properties, identity, options \\ %{}) do
    body =
      %{
        name: page,
        properties: strip_context(properties),
        context: context(properties),
        integrations: Map.get(options, :integrations)
      }
      |> identity_params(identity)

    body
    |> remove_nil_values()
    |> Jason.encode()
    |> post_or_return_error("page")
  end

  @doc """
  Identifies a user
  """
  def identify(traits, identity, options \\ %{}) do
    body =
      %{
        traits: traits,
        context: context(),
        integrations: Map.get(options, :integrations)
      }
      |> identity_params(identity)

    body
    |> remove_nil_values()
    |> Jason.encode()
    |> post_or_return_error("identify")
  end

  @doc """
  Aliases an anonymous user to a registered user
  """
  def alias(anonymous_id, user_id, options \\ %{}) do
    body = %{
      context: context(),
      integrations: Map.get(options, :integrations),
      previousId: anonymous_id,
      userId: user_id
    }

    body
    |> remove_nil_values()
    |> Jason.encode()
    |> post_or_return_error("alias")
  end

  def context(%{"context" => context}), do: Map.merge(context, context())
  def context(%{context: context}), do: Map.merge(context, context())
  def context(_properties), do: context()

  def context, do: %{library: %{name: "elixir-segment-api", version: @app_version}}

  def strip_context(properties) do
    properties
    |> Map.delete("context")
    |> Map.delete(:context)
  end

  def process_response_status_code(200), do: Logger.debug("#{__MODULE__} successfully called")

  def process_response_status_code(status_code),
    do: Logger.info("#{__MODULE__} not successfully called, returned #{status_code}")

  defp remove_nil_values(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp post_or_return_error({:ok, http_body}, path), do: post_to_segment(path, http_body)

  defp post_or_return_error({:error, _} = error, _), do: error

  defp post_to_segment(path, http_body),
    do: post("#{@endpoint}/#{path}", http_body, headers(), hackney: [pool: :segment])

  defp headers, do: [Authorization: auth_header(), "Content-Type": "application/json"]

  defp auth_header,
    do: "Basic #{Base.encode64(Application.get_env(:segment_api, :api_key, "") <> ":")}"

  defp identity_params(body, user_id: user_id, anonymous_id: anonymous_id),
    do: Map.merge(body, %{userId: user_id, anonymousId: anonymous_id})

  defp identity_params(body, user_id: user_id), do: Map.put(body, :userId, user_id)

  defp identity_params(body, anonymous_id: anonymous_id),
    do: Map.put(body, :anonymousId, anonymous_id)
end
