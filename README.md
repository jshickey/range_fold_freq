# Range Fold Freq

This project generates Excel reports showing the range-weighted fold frequency for defensive poker scenarios. It processes CSV files from the handclass project and calculates the sum of (percent_of_range * mean_fold_freq) grouped by board characteristics.

## How to Run

### Windows

After building the release with `mix release`, run the batch file wrapper with your directory path:

```batch
run_range_fold_freq.bat c:\prod\Test_Report_Container
```

The batch file accepts native Windows paths with backslashes and automatically handles path conversion.

### Unix/Linux/Mac

Run the release directly:

```bash
bin/range_fold_freq eval 'RangeFoldFreq.run("/path/to/directory")'
```

## Overview

The range_fold_freq tool:
- Processes defensive CSV files (*.out.csv) from the handclass project
- Groups data by the first 5 columns: board_texture, connectedness, pairedness, suitedness, broadways
- Calculates range_fold_freq as: Σ(percent_of_range × mean_fold_freq / 100)
- Generates Excel spreadsheets with two sheets (Unpaired and Single Paired)
- Includes column filters for easy data exploration

## Run in Development

```bash
cd /Users/jshickey/poker/range_fold_freq
mix run -e 'RangeFoldFreq.run("/Users/jshickey/poker/process_folder_test/bigger_single_flow_defensive")'
```

## Setup for Development

Install Elixir and Erlang:
```bash
scoop install erlang
scoop install elixir
```

Clone the Github repository and download all of the Elixir dependencies:
```bash
git clone git@github.com:jshickey/range_fold_freq.git
cd range_fold_freq
mix deps.get
```

## Input File Format

The tool expects defensive CSV files with the following columns:
- Columns 0-4: board_texture, connectedness, pairedness, suitedness, broadways
- Column 20: mean_fold_freq
- Column 21: percent_of_range

## Output

Excel files are generated with the naming pattern:
- `range_fold_freq.xlsx` (for single directory)
- `{directory_path}_range_fold_freq.xlsx` (for nested directories)

Each spreadsheet contains:
- **Unpaired sheet**: Data for unpaired board scenarios
- **Single Paired sheet**: Data for paired board scenarios
- **Columns**: Board Texture, Connectedness, Suitedness, Broadways, Range Fold Freq
- **Auto-filters**: Enabled on all columns for easy filtering

