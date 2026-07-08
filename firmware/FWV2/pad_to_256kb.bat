@echo off
set INBIN=%~1
set OUTBIN=%~2
if "%INBIN%"=="" (
  echo Usage: pad_to_256kb.bat input.bin output_256KB.bin
  exit /b 1
)
if "%OUTBIN%"=="" (
  echo Usage: pad_to_256kb.bat input.bin output_256KB.bin
  exit /b 1
)
powershell -ExecutionPolicy Bypass -File "%~dp0pad_to_256kb.ps1" -InBin "%INBIN%" -OutBin "%OUTBIN%"
