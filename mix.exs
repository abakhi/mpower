defmodule MPower.Mixfile do
  use Mix.Project

  def project do
    [app: :mpower,
     version: "1.0.1",
     elixir: "~> 1.2",
     description: "Elixir wrapper for MPowerPayments API",
     source_url: "https://github.com/abakhi/mpower",
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :httpoison]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:httpoison, "~> 0.8.2"},
     {:poison, "~> 2.1"},

     # Docs
     {:ex_doc, "~> 0.10", only: :docs},
     {:earmark, "~> 0.1", only: :docs}]
  end

  defp package do
    [
      maintainers: ["Yao Adzaku", "Kirk S. Agbenyegah"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/abakhi/mpower",
        "Documentation" => "http://hexdocs.pm/mpower"
      }
    ]
  end
end
