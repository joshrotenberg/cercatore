defmodule Cercatore.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/joshrotenberg/cercatore"

  def project do
    [
      app: :cercatore,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "Cercatore",
      source_url: @source_url,
      description: "BM25 full-text search with fuzzy matching for Elixir",
      dialyzer: [plt_file: {:no_warn, "_build/dev/dialyxir_#{System.otp_release()}.plt"}]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:simile, path: "../simile"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "Cercatore",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end
end
