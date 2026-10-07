defmodule SegmentAPITest do
  use ExUnit.Case, async: false

  alias Plug.Conn
  alias Req.Response
  alias Req.TransportError

  setup do
    bypass = Bypass.open()
    previous = Application.get_all_env(:segment_api)
    Application.put_env(:segment_api, :endpoint, "http://localhost:#{bypass.port}/v1")
    Application.put_env(:segment_api, :api_key, "segment-write-key")

    on_exit(fn ->
      Application.delete_env(:segment_api, :endpoint)
      Application.delete_env(:segment_api, :api_key)
      Application.put_all_env(segment_api: previous)
    end)

    %{bypass: bypass}
  end

  test "event operations send authenticated JSON with identities and library context", %{
    bypass: bypass
  } do
    cases = [
      {"track",
       fn ->
         SegmentAPI.track("Purchased", %{price: 12, context: %{locale: "nl"}},
           user_id: "user",
           anonymous_id: "anonymous"
         )
       end,
       %{
         "event" => "Purchased",
         "properties" => %{"price" => 12},
         "userId" => "user",
         "anonymousId" => "anonymous"
       }},
      {"page",
       fn ->
         SegmentAPI.page(
           "Checkout",
           %{"context" => %{"locale" => "nl"}},
           [anonymous_id: "anonymous"],
           %{integrations: %{All: false}}
         )
       end,
       %{
         "name" => "Checkout",
         "properties" => %{},
         "anonymousId" => "anonymous",
         "integrations" => %{"All" => false}
       }},
      {"identify", fn -> SegmentAPI.identify(%{email: "test@example.test"}, user_id: "user") end,
       %{"traits" => %{"email" => "test@example.test"}, "userId" => "user"}},
      {"alias", fn -> SegmentAPI.alias("anonymous", "user") end,
       %{"previousId" => "anonymous", "userId" => "user"}}
    ]

    for {path, operation, expected} <- cases do
      Bypass.expect_once(bypass, "POST", "/v1/" <> path, fn conn ->
        assert Conn.get_req_header(conn, "authorization") == [
                 "Basic " <> Base.encode64("segment-write-key:")
               ]

        assert Conn.get_req_header(conn, "content-type") == ["application/json"]
        {:ok, body, conn} = Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert Map.drop(decoded, ["context"]) == expected
        assert decoded["context"]["library"]["name"] == "elixir-segment-api"
        assert is_binary(decoded["context"]["library"]["version"])
        if path in ["track", "page"], do: assert(decoded["context"]["locale"] == "nl")

        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, ~s({"success":true}))
      end)

      assert {:ok, %Response{status: 200, body: ~s({"success":true})}} = operation.()
    end
  end

  test "HTTP failures retain status and body without retrying event posts", %{bypass: bypass} do
    for status <- [401, 429, 503] do
      Bypass.expect_once(bypass, "POST", "/v1/track", fn conn ->
        conn
        |> Conn.put_resp_header("retry-after", "0")
        |> Conn.resp(status, "rejected")
      end)

      assert {:ok, %Response{status: ^status, body: "rejected"}} =
               SegmentAPI.track("Purchased", %{}, user_id: "user")
    end
  end

  test "redirect responses do not resend event posts", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/track", fn conn ->
      conn
      |> Conn.put_resp_header("location", "/unexpected")
      |> Conn.resp(307, "redirect")
    end)

    assert {:ok, %Response{status: 307, body: "redirect"}} =
             SegmentAPI.track("Purchased", %{}, user_id: "user")
  end

  test "connection failures return transport errors", %{bypass: bypass} do
    Bypass.down(bypass)

    assert {:error, %TransportError{reason: :econnrefused}} =
             SegmentAPI.identify(%{}, user_id: "user")
  end

  test "encoding failures return without sending an event" do
    assert {:error, %Protocol.UndefinedError{}} =
             SegmentAPI.track("Purchased", %{invalid: self()}, user_id: "user")
  end
end
