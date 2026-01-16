defmodule Mix.Tasks.ParseCsvs do
  use Mix.Task

  @shortdoc "Parses CSV files in a directory and generates range fold frequency reports"

  def run([directory]) do
    Mix.Task.run("app.start")
    RangeFoldFreq.run(directory)
  end

  def run(_) do
    Mix.shell().error("Usage: mix parse_csvs <directory>")
  end
end
