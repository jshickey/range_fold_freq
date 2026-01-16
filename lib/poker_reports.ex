defmodule RangeFoldFreq do
  def run(directory) do
    directory = String.replace(directory, "\\", "/")
    root_directory = directory

    # Find all directories containing CSV files
    csv_directories = find_csv_directories(directory)

    IO.puts("\nFound #{length(csv_directories)} directories with CSV files")

    # Generate reports for each directory
    results =
      Enum.with_index(csv_directories, 1)
      |> Enum.map(fn {dir, index} ->
        IO.puts(
          "[#{index}/#{length(csv_directories)}] Processing: #{Path.relative_to(dir, root_directory)}"
        )

        generate_report(dir, root_directory)
      end)

    # Summarize results
    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _} -> status == :error end)

    IO.puts("\n=== Summary ===")
    IO.puts("Successfully generated: #{successful} reports")
    IO.puts("Failed: #{failed} reports")

    # Create reports directory with links/copies to all Excel files
    create_reports_directory(root_directory, results)

    {:ok, results}
  end

  defp find_csv_directories(root_directory) do
    # Find all .out.csv files recursively
    csv_files = Path.join(root_directory, "**/*.out.csv") |> Path.wildcard()

    # Group by directory and return unique directories
    csv_files
    |> Enum.map(&Path.dirname/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp generate_report(directory, root_directory) do
    case CSVParser.parse_csvs(directory) do
      {rows, _unique_values} ->
        {unpaired, paired} = group_data(rows)
        unpaired_broadways_map = build_broadways_map(unpaired)
        paired_broadways_map = build_broadways_map(paired)

        # Generate filename from relative path
        filename_without_ext = generate_filename_without_ext(directory, root_directory)

        ExcelGenerator.generate_excel(
          unpaired,
          paired,
          unpaired_broadways_map,
          paired_broadways_map,
          directory,
          filename_without_ext
        )

      error ->
        {:error, error}
    end
  end

  defp generate_filename_without_ext(directory, root_directory) do
    # Get the relative path from root to current directory
    relative_path = Path.relative_to(directory, root_directory)

    # If relative path is "." (current directory), return nil for default filename
    # Otherwise replace path separators with underscores (no extension)
    case relative_path do
      "." -> nil
      path -> String.replace(path, "/", "_")
    end
  end

  defp create_reports_directory(root_directory, results) do
    reports_dir = Path.join(root_directory, "reports")

    # Create reports directory if it doesn't exist
    File.mkdir_p!(reports_dir)

    IO.puts("\n=== Creating Reports Directory ===")
    IO.puts("Reports directory: #{reports_dir}")

    # Process each successful result
    successful_reports =
      results
      |> Enum.filter(fn {status, _} -> status == :ok end)
      |> Enum.map(fn {:ok, excel_path} -> excel_path end)

    # Copy each Excel file to the reports directory
    Enum.each(successful_reports, fn excel_path ->
      filename = Path.basename(excel_path)
      target_path = Path.join(reports_dir, filename)
      File.cp!(excel_path, target_path)
    end)

    IO.puts("Copied #{length(successful_reports)} reports to #{reports_dir}")
  end

  defp group_data(rows) do
    {unpaired, paired} =
      Enum.split_with(rows, fn row -> row.pairedness == :unpaired end)

    # Group unpaired data
    unpaired_grouped = group_by_categories(unpaired)

    # Group paired data (all paired types)
    paired_grouped = group_by_categories(paired)

    {unpaired_grouped, paired_grouped}
  end

  defp group_by_categories(rows) do
    rows
    |> Enum.group_by(& &1.board_texture)
    |> Enum.map(fn {board_texture, rows} ->
      connectedness_grouped =
        Enum.group_by(rows, & &1.connectedness)
        |> Enum.map(fn {connectedness, rows} ->
          suitedness_grouped =
            Enum.group_by(rows, & &1.suitedness)
            |> Enum.map(fn {suitedness, rows} ->
              broadways_grouped =
                Enum.group_by(rows, & &1.broadways)
                |> Enum.map(fn {broadways, rows} ->
                  # Each row already has range_fold_freq calculated
                  # Just take the first one since they should all be the same for this group
                  range_fold_freq = List.first(rows).range_fold_freq
                  {broadways, range_fold_freq}
                end)

              {suitedness, broadways_grouped}
            end)

          {connectedness, suitedness_grouped}
        end)

      {board_texture, connectedness_grouped}
    end)
  end

  defp build_broadways_map(grouped_data) do
    Enum.reduce(grouped_data, %{}, fn {board_texture, connectedness_grouped}, acc ->
      Enum.reduce(connectedness_grouped, acc, fn {connectedness, suitedness_grouped}, acc ->
        Enum.reduce(suitedness_grouped, acc, fn {suitedness, broadways_grouped}, acc ->
          broadways_values = Enum.map(broadways_grouped, fn {broadways, _} -> broadways end)
          key = {board_texture, connectedness, suitedness}
          Map.put(acc, key, broadways_values)
        end)
      end)
    end)
  end
end
