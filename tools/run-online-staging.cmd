@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-online-staging.ps1" %*
exit /b %ERRORLEVEL%
