@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bootstrap.ps1"
if errorlevel 1 (
  echo.
  echo Setup that bai. Xem thong bao loi phia tren.
  pause
  exit /b 1
)
echo.
echo Setup FinTrack hoan tat.
pause
