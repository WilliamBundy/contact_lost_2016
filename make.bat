@echo off

set zip="c:\Program Files\7-Zip\7z.exe"
set archive="contactlost.zip"

pushd src
%zip% a %archive% *
popd

del %archive%
move src\%archive% . >NUL

if "%~1"=="run" goto RUN
if "%~2"=="run" goto RUN

GOTO END

:RUN
start love %archive%

:END

