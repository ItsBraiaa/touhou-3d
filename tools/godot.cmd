@echo off
rem Calls tools/godot.ps1 with the execution policy bypassed. Arguments pass through untouched.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0godot.ps1" %*
exit /b %ERRORLEVEL%
