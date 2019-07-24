choco install -y --no-progress msys2 pacman
call %USERPROFILE%\project\scripts\windows\msys2_prepare.bat
path %WIN_MSYS2_ROOT%\mingw64\bin;%WIN_MSYS2_ROOT%\usr\bin;%PATH%
call %USERPROFILE%\project\ci\appveyor\build.bat
