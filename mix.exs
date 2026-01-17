defmodule RangeFoldFreq.MixProject do
  use Mix.Project

  def project do
    [
      app: :range_fold_freq,
      version: "2.0.2",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        range_fold_freq: [
          include_executables_for: [:unix, :windows],
          applications: [runtime_tools: :permanent],
          steps: [:assemble, &copy_batch_file/1]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Copy the Windows batch file wrapper to the release directory
  defp copy_batch_file(release) do
    File.cp!("rel/run_range_fold_freq.bat", Path.join(release.path, "run_range_fold_freq.bat"))
    release
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_csv, "~> 1.1"},
      {:elixlsx, "~> 0.6.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
