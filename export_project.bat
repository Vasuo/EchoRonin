@echo off
set OUTPUT=project_dump.txt

echo Сбор файлов проекта...
if exist %OUTPUT% del %OUTPUT%

for /r %%F in (*.gd) do (
    echo %%F >> %OUTPUT%
    type "%%F" >> %OUTPUT%
    echo. >> %OUTPUT%
)

for /r %%F in (*.tscn) do (
    echo %%F >> %OUTPUT%
    type "%%F" >> %OUTPUT%
    echo. >> %OUTPUT%
)

for /r %%F in (*.tres) do (
    echo %%F >> %OUTPUT%
    type "%%F" >> %OUTPUT%
    echo. >> %OUTPUT%
)

if exist project.godot (
    echo project.godot >> %OUTPUT%
    type project.godot >> %OUTPUT%
)

echo Готово. Файл: %OUTPUT%
pause