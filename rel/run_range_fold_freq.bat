@echo off
REM Windows batch file wrapper for range_fold_freq
REM Usage: run_range_fold_freq.bat <directory_path>

if "%~1"=="" (
    echo Error: No directory path provided
    echo.
    echo Usage: run_range_fold_freq.bat ^<directory_path^>
    echo Example: run_range_fold_freq.bat c:\prod\Test_Report_Container
    exit /b 1
)

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Convert the user's path argument to use forward slashes for Elixir
set INPUT_DIR=%~1
set INPUT_DIR=%INPUT_DIR:\=/%

REM Call the range_fold_freq release with the normalized path
"%SCRIPT_DIR%bin\range_fold_freq.bat" eval "RangeFoldFreq.run(\"%INPUT_DIR%\")"
