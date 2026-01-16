defmodule CSVParser do
  alias NimbleCSV.RFC4180, as: CSV

  def parse_csvs(directory) do
    # Initialize accumulators for rows grouped by first 5 columns
    initial_acc = %{
      grouped_rows: %{},
      unique_values: %{
        board_texture: MapSet.new(),
        connectedness: MapSet.new(),
        pairedness: MapSet.new(),
        suitedness: MapSet.new(),
        broadways: MapSet.new()
      }
    }

    # Process all CSV files in the directory
    files =
      directory
      |> Path.join("*.out.csv")
      |> Path.wildcard()

    result =
      Enum.reduce(files, initial_acc, fn file_path, acc ->
        parse_file(file_path, acc)
      end)

    # Calculate range_fold_freq for each group
    rows_with_range_fold_freq = calculate_range_fold_freq(result.grouped_rows)

    {rows_with_range_fold_freq, result.unique_values}
  end

  defp parse_file(file_path, acc) do
    try do
      # Read the entire file to check if it's empty
      file_content = File.read!(file_path)

      if String.trim(file_content) == "" do
        acc
      else
        # Parse the CSV file (skip header row)
        rows =
          file_path
          |> File.stream!()
          |> CSV.parse_stream(skip_headers: true)
          |> Enum.to_list()

        case rows do
          [] ->
            acc

          data_rows ->
            # Process data rows
            Enum.reduce(data_rows, acc, fn row, %{grouped_rows: groups, unique_values: uniques} ->
              try do
                # Parse row to extract needed fields
                row_map = parse_row(row)

                # Create key from first 5 columns
                key = {
                  row_map.board_texture,
                  row_map.connectedness,
                  row_map.pairedness,
                  row_map.suitedness,
                  row_map.broadways
                }

                # Add this row's data to the group
                existing_data = Map.get(groups, key, [])
                updated_groups = Map.put(groups, key, [row_map | existing_data])

                # Update unique values
                updated_uniques = %{
                  board_texture: MapSet.put(uniques.board_texture, row_map.board_texture),
                  connectedness: MapSet.put(uniques.connectedness, row_map.connectedness),
                  pairedness: MapSet.put(uniques.pairedness, row_map.pairedness),
                  suitedness: MapSet.put(uniques.suitedness, row_map.suitedness),
                  broadways: MapSet.put(uniques.broadways, row_map.broadways)
                }

                %{grouped_rows: updated_groups, unique_values: updated_uniques}
              rescue
                _e ->
                  %{grouped_rows: groups, unique_values: uniques}
              end
            end)
        end
      end
    rescue
      _e ->
        acc
    end
  end

  defp parse_row(row) do
    %{
      board_texture: String.to_atom(Enum.at(row, 0)),
      connectedness: String.to_atom(Enum.at(row, 1)),
      pairedness: String.to_atom(Enum.at(row, 2)),
      suitedness: String.to_atom(Enum.at(row, 3)),
      broadways: String.to_atom(Enum.at(row, 4)),
      mean_fold_freq: parse_float(Enum.at(row, 20)),
      percent_of_range: parse_float(Enum.at(row, 21))
    }
  end

  defp calculate_range_fold_freq(grouped_rows) do
    Enum.map(grouped_rows, fn {{board_texture, connectedness, pairedness, suitedness, broadways}, rows} ->
      # Calculate sum of (percent_of_range * mean_fold_freq) for this group
      range_fold_freq =
        rows
        |> Enum.reduce(0.0, fn row, acc ->
          if row.percent_of_range && row.mean_fold_freq do
            acc + (row.percent_of_range * row.mean_fold_freq / 100.0)
          else
            acc
          end
        end)

      %{
        board_texture: board_texture,
        connectedness: connectedness,
        pairedness: pairedness,
        suitedness: suitedness,
        broadways: broadways,
        range_fold_freq: range_fold_freq
      }
    end)
  end

  defp parse_float(value) when is_nil(value) or value == "", do: nil
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value / 1.0

  defp parse_float(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {float, _} -> float
      :error -> nil
    end
  end

  defp parse_float(_value), do: nil
end
