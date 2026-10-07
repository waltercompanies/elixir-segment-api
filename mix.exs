defmodule SegmentAPI.MixProject do
  use Mix.Project

  def project do
    [
      app: :segment_api,
      version: "0.2.3",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.1"},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:req, "~> 0.7.0"},
      {:bypass, "~> 2.1", only: :test}
    ]
  end
end
