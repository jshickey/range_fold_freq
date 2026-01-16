defmodule ExcelGenerator do
  alias Elixlsx.{Sheet, Workbook}

  def generate_excel(
        unpaired_data,
        paired_data,
        unpaired_broadways_map,
        paired_broadways_map,
        directory,
        filename_prefix \\ nil
      ) do
    board_textures = [
      :ahi_flop,
      :KF_no_overcard_turn_or_river,
      :QF_no_overcard_turn_or_river,
      :JF_no_overcard_turn_or_river,
      :TF_no_overcard_turn_or_river,
      :KF_overcard_turn_no_overcard_river,
      :QF_overcard_turn_no_overcard_river,
      :JF_overcard_turn_no_overcard_river,
      :TF_overcard_turn_no_overcard_river,
      :KF_no_overcard_turn_overcard_river,
      :QF_no_overcard_turn_overcard_river,
      :JF_no_overcard_turn_overcard_river,
      :TF_no_overcard_turn_overcard_river,
      :LF_no_overcard_turn_or_river,
      :LF_no_overcard_turn_overcard_river,
      :LF_overcard_turn_and_river,
      :LF_overcard_turn_no_overcard_river,
      :TB_no_overcard_turn_or_river,
      :TB_no_overcard_turn_overcard_river,
      :TB_overcard_turn_and_river,
      :TB_overcard_turn_no_overcard_river
    ]

    connectedness_values = [:connected, :disconnected, :one_straight]
    suitedness_values = [:two_suit, :three_suit, :four_suit]

    unpaired_sheet =
      create_sheet(
        "Unpaired",
        unpaired_data,
        unpaired_broadways_map,
        board_textures,
        connectedness_values,
        suitedness_values
      )

    paired_sheet =
      create_sheet(
        "Single Paired",
        paired_data,
        paired_broadways_map,
        board_textures,
        connectedness_values,
        suitedness_values
      )

    workbook = %Workbook{sheets: [unpaired_sheet, paired_sheet]}

    # Build filename with optional prefix
    filename =
      if filename_prefix do
        "#{filename_prefix}_range_fold_freq.xlsx"
      else
        "range_fold_freq.xlsx"
      end

    output_path = Path.join(directory, filename)

    case Elixlsx.write_to(workbook, output_path) do
      {:ok, _} ->
        # Add autofilter to both sheets
        add_autofilter_to_excel(output_path)
        {:ok, output_path}

      error ->
        error
    end
  end

  defp add_autofilter_to_excel(excel_path) do
    # Create a temporary directory for extraction
    temp_dir = excel_path <> "_temp"
    File.rm_rf!(temp_dir)
    File.mkdir_p!(temp_dir)

    # Unzip the Excel file using Erlang's :zip module
    :zip.unzip(String.to_charlist(excel_path), [{:cwd, String.to_charlist(temp_dir)}])

    # Add autofilter to both sheets
    add_autofilter_to_sheet_file(temp_dir, "sheet1.xml")
    add_autofilter_to_sheet_file(temp_dir, "sheet2.xml")

    # Get all files in the temp directory recursively
    files = get_all_files_for_zip(temp_dir)

    # Create zip in memory first, then write to file
    File.rm!(excel_path)
    
    case :zip.create(String.to_charlist(Path.basename(excel_path)), files, [:memory]) do
      {:ok, {_filename, binary}} ->
        # Write the binary to the file
        File.write!(excel_path, binary)
        # Clean up temp directory
        File.rm_rf!(temp_dir)
        :ok
      
      {:error, reason} ->
        # Clean up temp directory even on error
        File.rm_rf!(temp_dir)
        {:error, reason}
    end
  end

  defp get_all_files_for_zip(temp_dir) do
    Path.wildcard(Path.join(temp_dir, "**/*"), match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(fn file_path ->
      relative_path = Path.relative_to(file_path, temp_dir)
      {String.to_charlist(relative_path), File.read!(file_path)}
    end)
  end

  defp add_autofilter_to_sheet_file(temp_dir, sheet_filename) do
    sheet_path = Path.join([temp_dir, "xl", "worksheets", sheet_filename])

    case File.read(sheet_path) do
      {:ok, content} ->
        modified_content = add_autofilter_to_sheet_content(content)
        File.write!(sheet_path, modified_content)

      {:error, _} ->
        :ok
    end
  end

  defp add_autofilter_to_sheet_content(content) do
    # Extract the last row number and last column
    content_str = to_string(content)

    last_row =
      Regex.scan(~r/row r="(\d+)"/, content_str)
      |> Enum.map(fn [_, num] -> String.to_integer(num) end)
      |> Enum.max(fn -> 1 end)

    # Extract the last column letter from cell references
    last_col =
      Regex.scan(~r/c r="([A-Z]+)\d+"/, content_str)
      |> Enum.map(fn [_, col] -> col end)
      |> Enum.max_by(&column_to_number/1, fn -> "E" end)

    # Add autofilter XML after </sheetData> but before <pageMargins>
    autofilter_xml = "\n<autoFilter ref=\"A1:#{last_col}#{last_row}\"/>"
    updated_content = String.replace(content_str, "</sheetData>", "</sheetData>#{autofilter_xml}")

    updated_content
  end

  defp column_to_number(col) do
    col
    |> String.to_charlist()
    |> Enum.reduce(0, fn char, acc -> acc * 26 + (char - ?A + 1) end)
  end

  defp create_sheet(
         sheet_name,
         data,
         broadways_map,
         board_textures,
         connectedness_values,
         suitedness_values
       ) do
    # Header row with just one value column
    header_row = [
      ["Board Texture", bold: true],
      ["Connectedness", bold: true],
      ["Suitedness", bold: true],
      ["Broadways", bold: true],
      ["Range Fold Freq", bold: true]
    ]

    data_rows =
      build_data_rows(
        data,
        broadways_map,
        board_textures,
        connectedness_values,
        suitedness_values
      )

    all_rows = [header_row | data_rows]

    # Set column widths for the first 4 label columns (1-based indexing)
    col_widths = %{
      # Board Texture column (A)
      1 => 35.0,
      # Connectedness column (B)
      2 => 15.0,
      # Suitedness column (C)
      3 => 12.0,
      # Broadways column (D)
      4 => 18.0,
      # Range Fold Freq column (E)
      5 => 15.0
    }

    %Sheet{name: sheet_name, rows: all_rows, col_widths: col_widths}
  end

  defp build_data_rows(
         data,
         broadways_map,
         board_textures,
         connectedness_values,
         suitedness_values
       ) do
    # Each row is a board_texture/connectedness/suitedness/broadways combination
    for board_texture <- board_textures,
        connectedness <- connectedness_values,
        suitedness <- suitedness_values,
        broadways <- Map.get(broadways_map, {board_texture, connectedness, suitedness}, []) do
      # First 4 columns: board identifiers
      row_labels = [
        to_string(board_texture),
        to_string(connectedness),
        to_string(suitedness),
        to_string(broadways)
      ]

      # Get the range_fold_freq value for this combination
      range_fold_freq =
        get_range_fold_freq(
          data,
          board_texture,
          connectedness,
          suitedness,
          broadways
        )

      # Format the value (no color shading)
      value_cell =
        if range_fold_freq do
          Float.round(range_fold_freq, 2)
        else
          ""
        end

      row_labels ++ [value_cell]
    end
  end

  defp get_range_fold_freq(
         data,
         board_texture,
         connectedness,
         suitedness,
         broadways
       ) do
    # Navigate through the nested structure to find the value
    case Enum.find(data, fn {bt, _} -> bt == board_texture end) do
      {^board_texture, connectedness_grouped} ->
        case Enum.find(connectedness_grouped, fn {c, _} -> c == connectedness end) do
          {^connectedness, suitedness_grouped} ->
            case Enum.find(suitedness_grouped, fn {s, _} -> s == suitedness end) do
              {^suitedness, broadways_grouped} ->
                case Enum.find(broadways_grouped, fn {b, _} -> b == broadways end) do
                  {^broadways, range_fold_freq} ->
                    range_fold_freq

                  _ ->
                    nil
                end

              _ ->
                nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
