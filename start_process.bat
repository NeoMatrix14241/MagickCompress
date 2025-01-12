@echo off
color 0a
cls
title MagickCompressor - ImageMagick Batch Image Compressor
if not exist "input" mkdir input
if not exist "archive" mkdir archive
if not exist "output" mkdir output
if not exist "logs" mkdir logs
cls
pwsh.exe -ExecutionPolicy RemoteSigned -File "compress.ps1"
echo.
echo.
echo PROCESSES FOR COMPRESSION OF TIF FILES DONE, CHECK "output" FOLDER FOR EVALUATION
echo.
pause