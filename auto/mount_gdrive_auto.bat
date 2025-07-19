@echo off
setlocal EnableDelayedExpansion

REM ===== CONFIG =====
set "RCLONE_FOLDER=%~dp0rclone"
set "RCLONE_EXE=%RCLONE_FOLDER%\rclone.exe"
set "REMOTE_NAME=gdrive"
set "DRIVE_LETTER=X:"
set "SERVICE_ACCOUNT_FILE=%~dp0rclone-gdrive.json"

REM ===== DEPENDENCY URLs =====
set "RCLONE_URL=https://downloads.rclone.org/rclone-current-windows-amd64.zip"
set "WINFSP_URL=https://github.com/billziss-gh/winfsp/releases/latest/download/winfsp-2.1.23421.msi"

REM ===== UTILITY FUNCTIONS =====

:download
echo Downloading %1...
powershell -Command "Invoke-WebRequest -Uri %1 -OutFile %2"
goto :eof

:unzip
powershell -Command "Expand-Archive -Path '%1' -DestinationPath '%2' -Force"
goto :eof

REM ===== INSTALL rclone IF MISSING =====
if not exist "%RCLONE_EXE%" (
    echo rclone not found. Installing...

    set "RCLONE_ZIP=%TEMP%\rclone.zip"
    call :download "%RCLONE_URL%" "%RCLONE_ZIP%"

    mkdir "%RCLONE_FOLDER%" >nul 2>&1
    call :unzip "%RCLONE_ZIP%" "%RCLONE_FOLDER%-unzipped"

    REM Move actual rclone.exe from subfolder
    for /D %%d in ("%RCLONE_FOLDER%-unzipped\rclone-*") do (
        move "%%d\rclone.exe" "%RCLONE_FOLDER%\" >nul
    )
    rmdir /s /q "%RCLONE_FOLDER%-unzipped"
    del "%RCLONE_ZIP%"
)

REM ===== INSTALL WinFsp IF MISSING =====
where winfsp-launcher >nul 2>&1
if errorlevel 1 (
    echo WinFsp not found. Installing...

    set "WINFSP_MSI=%TEMP%\winfsp.msi"
    call :download "%WINFSP_URL%" "%WINFSP_MSI%"
    msiexec /i "%WINFSP_MSI%" /quiet /norestart
    del "%WINFSP_MSI%"
)

REM ===== CHECK SERVICE ACCOUNT =====
if not exist "%SERVICE_ACCOUNT_FILE%" (
    echo ERROR: Service account JSON not found at %SERVICE_ACCOUNT_FILE%
    pause
    exit /b
)

REM ===== CREATE REMOTE IF NEEDED =====
echo Checking if rclone remote "%REMOTE_NAME%" exists...
"%RCLONE_EXE%" listremotes | find "%REMOTE_NAME%:" >nul
if errorlevel 1 (
    echo Creating rclone remote...
    "%RCLONE_EXE%" config create %REMOTE_NAME% drive service_account_file="%SERVICE_ACCOUNT_FILE%"
)

REM ===== MOUNT DRIVE =====
echo Mounting Google Drive to %DRIVE_LETTER%...
"%RCLONE_EXE%" mount %REMOTE_NAME%: %DRIVE_LETTER% --vfs-cache-mode writes

pause
