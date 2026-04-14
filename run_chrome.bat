@echo off
REM Force run Flutter on Chrome, killing Edge if needed

echo Killing any running Edge windows...
taskkill /F /IM msedge.exe 2>nul

echo Killing any Flutter processes...
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM chromedriver.exe 2>nul

echo.
echo Cleaning Flutter...
call flutter clean

echo.
echo Getting packages...
call flutter pub get

echo.
echo Running on Chrome...
set CHROME_EXECUTABLE=C:\Program Files\Google\Chrome\Application\chrome.exe
call flutter run -d chrome -v

pause
