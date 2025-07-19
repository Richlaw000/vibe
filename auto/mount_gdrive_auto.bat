@echo off
setlocal EnableDelayedExpansion

REM ============================================================================
REM Google Drive Auto-Installing Mount Script using rclone
REM ============================================================================
REM This script will automatically download and install:
REM - rclone (if not found)
REM - WinFsp (if not found) 
REM - Configure Google Drive remote (if not configured)
REM ============================================================================

REM Configuration - Modify these variables as needed
set REMOTE_NAME=gdrive
set DRIVE_LETTER=X:
set VFS_CACHE_MODE=writes
set LOG_LEVEL=INFO
set LOG_FILE=%~dp0rclone_mount.log

REM Installation paths
set RCLONE_DIR=%~dp0rclone
set RCLONE_EXE=%RCLONE_DIR%\rclone.exe
set TEMP_DIR=%~dp0temp

REM Download URLs (these may need updating periodically)
set RCLONE_URL=https://downloads.rclone.org/rclone-current-windows-amd64.zip
set WINFSP_URL=https://github.com/billziss-gh/winfsp/releases/download/v1.12/winfsp-1.12.22339.msi

REM ============================================================================
REM AUTHENTICATION CONFIGURATION - SERVICE ACCOUNT METHOD
REM ============================================================================

REM METHOD 1: Auto-detect service account JSON file in same folder
REM The script will automatically look for any .json file in the same directory
REM Just place your service account JSON file in the same folder as this bat file!

REM METHOD 2: Specify exact JSON filename (if you have multiple JSON files)
REM Uncomment and set the exact filename:
REM set SERVICE_ACCOUNT_FILENAME=your-service-account-key.json

REM METHOD 3: Use full path (if JSON file is elsewhere)
REM Uncomment and set the full path:
REM set SERVICE_ACCOUNT_FILE=C:\path\to\service-account-key.json

REM ============================================================================

REM Advanced options (uncomment and modify as needed)
REM set ADDITIONAL_FLAGS=--read-only
REM set ADDITIONAL_FLAGS=--vfs-cache-mode full --vfs-cache-max-size 1G
REM set ADDITIONAL_FLAGS=--transfers 4 --checkers 8

echo ============================================================================
echo Google Drive Auto-Installing Mount Script
echo ============================================================================
echo Remote Name: %REMOTE_NAME%
echo Drive Letter: %DRIVE_LETTER%
echo Cache Mode: %VFS_CACHE_MODE%
echo Log File: %LOG_FILE%
echo ============================================================================

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator for installations!
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

REM Create temp directory
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM Function to download files using PowerShell
set "DOWNLOAD_CMD=powershell -Command "& {[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%URL%' -OutFile '%OUTPUT%' -UseBasicParsing}""

REM ============================================================================
REM Auto-detect Service Account JSON file
REM ============================================================================
echo.
echo Looking for service account JSON file...

REM First check if specific filename is set
if defined SERVICE_ACCOUNT_FILENAME (
    set SERVICE_ACCOUNT_FILE=%~dp0%SERVICE_ACCOUNT_FILENAME%
    if exist "!SERVICE_ACCOUNT_FILE!" (
        echo ✓ Found specified service account file: !SERVICE_ACCOUNT_FILE!
        goto service_account_found
    ) else (
        echo ❌ Specified service account file not found: !SERVICE_ACCOUNT_FILE!
    )
)

REM If SERVICE_ACCOUNT_FILE is already set with full path, use it
if defined SERVICE_ACCOUNT_FILE (
    if exist "%SERVICE_ACCOUNT_FILE%" (
        echo ✓ Found service account file: %SERVICE_ACCOUNT_FILE%
        goto service_account_found
    ) else (
        echo ❌ Service account file not found: %SERVICE_ACCOUNT_FILE%
        set SERVICE_ACCOUNT_FILE=
    )
)

REM Auto-detect JSON files in the same directory
echo Scanning for JSON files in current directory: %~dp0
set JSON_COUNT=0
set FOUND_JSON=

for %%f in ("%~dp0*.json") do (
    set /a JSON_COUNT+=1
    set FOUND_JSON=%%f
    echo Found JSON file: %%f
)

if %JSON_COUNT%==1 (
    set SERVICE_ACCOUNT_FILE=%FOUND_JSON%
    echo ✓ Auto-detected service account file: !SERVICE_ACCOUNT_FILE!
    goto service_account_found
) else if %JSON_COUNT%==0 (
    echo ❌ No JSON files found in current directory
    echo Please place your service account JSON file in: %~dp0
    set SERVICE_ACCOUNT_FILE=
) else (
    echo ❌ Multiple JSON files found. Please specify which one to use:
    set /a COUNTER=0
    for %%f in ("%~dp0*.json") do (
        set /a COUNTER+=1
        echo   !COUNTER!. %%~nxf
        set JSON_!COUNTER!=%%f
    )
    echo.
    set /p JSON_CHOICE="Enter the number of the JSON file to use (1-%JSON_COUNT%): "
    
    if defined JSON_!JSON_CHOICE! (
        call set SERVICE_ACCOUNT_FILE=%%JSON_!JSON_CHOICE!%%
        echo ✓ Selected service account file: !SERVICE_ACCOUNT_FILE!
    ) else (
        echo Invalid selection. Please run the script again.
        pause
        exit /b 1
    )
)

:service_account_found
echo.
echo Checking rclone installation...

REM First check if rclone is in PATH
where rclone >nul 2>&1
if %errorLevel% equ 0 (
    echo ✓ rclone found in PATH
    set RCLONE_CMD=rclone
) else (
    REM Check if rclone exists in local directory
    if exist "%RCLONE_EXE%" (
        echo ✓ rclone found in local directory: %RCLONE_DIR%
        set RCLONE_CMD="%RCLONE_EXE%"
    ) else (
        echo ❌ rclone not found. Downloading and installing...
        
        REM Download rclone
        echo Downloading rclone from: %RCLONE_URL%
        set URL=%RCLONE_URL%
        set OUTPUT=%TEMP_DIR%\rclone.zip
        %DOWNLOAD_CMD%
        
        if !errorLevel! neq 0 (
            echo ERROR: Failed to download rclone!
            echo Please check your internet connection or download manually from: https://rclone.org/downloads/
            pause
            exit /b 1
        )
        
        REM Extract rclone using PowerShell
        echo Extracting rclone...
        powershell -Command "Expand-Archive -Path '%TEMP_DIR%\rclone.zip' -DestinationPath '%TEMP_DIR%' -Force"
        
        REM Find the extracted rclone folder and copy rclone.exe
        for /d %%i in ("%TEMP_DIR%\rclone-*") do (
            if exist "%%i\rclone.exe" (
                if not exist "%RCLONE_DIR%" mkdir "%RCLONE_DIR%"
                copy "%%i\rclone.exe" "%RCLONE_EXE%" >nul
                copy "%%i\*.txt" "%RCLONE_DIR%\" >nul 2>&1
                echo ✓ rclone installed to: %RCLONE_DIR%
                set RCLONE_CMD="%RCLONE_EXE%"
                goto rclone_installed
            )
        )
        
        echo ERROR: Failed to extract rclone.exe!
        pause
        exit /b 1
        
        :rclone_installed
    )
)

REM ============================================================================
REM Check and Install WinFsp
REM ============================================================================
echo.
echo Checking WinFsp installation...

if exist "C:\Program Files (x86)\WinFsp" (
    echo ✓ WinFsp found at: C:\Program Files (x86)\WinFsp
) else if exist "C:\Program Files\WinFsp" (
    echo ✓ WinFsp found at: C:\Program Files\WinFsp
) else (
    echo ❌ WinFsp not found. Downloading and installing...
    
    REM Download WinFsp
    echo Downloading WinFsp from: %WINFSP_URL%
    set URL=%WINFSP_URL%
    set OUTPUT=%TEMP_DIR%\winfsp.msi
    %DOWNLOAD_CMD%
    
    if !errorLevel! neq 0 (
        echo ERROR: Failed to download WinFsp!
        echo Please download manually from: https://github.com/billziss-gh/winfsp/releases
        pause
        exit /b 1
    )
    
    REM Install WinFsp silently
    echo Installing WinFsp...
    msiexec /i "%TEMP_DIR%\winfsp.msi" /quiet /norestart
    
    REM Wait a moment for installation to complete
    timeout /t 5 /nobreak >nul
    
    REM Verify installation
    if exist "C:\Program Files (x86)\WinFsp" (
        echo ✓ WinFsp installed successfully
    ) else if exist "C:\Program Files\WinFsp" (
        echo ✓ WinFsp installed successfully  
    ) else (
        echo ERROR: WinFsp installation may have failed!
        echo Please reboot and try again, or install manually.
        pause
        exit /b 1
    )
)

REM ============================================================================
REM Check and Install rclone
REM ============================================================================
REM ============================================================================
REM Configure Google Drive Remote
REM ============================================================================
echo.
echo Checking Google Drive remote configuration...

REM Check if the remote is configured
%RCLONE_CMD% listremotes | findstr /i "%REMOTE_NAME%:" >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ Remote '%REMOTE_NAME%' is not configured!
    
    REM If we have a service account file, configure automatically
    if defined SERVICE_ACCOUNT_FILE (
        echo ✓ Service account file found. Configuring Google Drive remote automatically...
        %RCLONE_CMD% config create %REMOTE_NAME% drive service_account_file "%SERVICE_ACCOUNT_FILE%"
        if !errorLevel! equ 0 (
            echo ✓ Google Drive remote '%REMOTE_NAME%' configured successfully!
        ) else (
            echo ❌ Failed to configure remote with service account!
            echo Please check that:
            echo   - The JSON file is valid
            echo   - You have shared your Google Drive with the service account email
            echo   - The service account has the necessary permissions
            pause
            exit /b 1
        )
    ) else (
        echo.
        echo You need to configure Google Drive access. Choose an option:
        echo 1. Interactive setup (recommended for first-time users)
        echo 2. I have a service account JSON file (will prompt for path)
        echo 3. I have an existing rclone.conf file
        echo 4. Skip and configure manually later
        echo.
        set /p SETUP_CHOICE="Enter your choice (1-4): "
        
        if "!SETUP_CHOICE!"=="1" (
            echo.
            echo Starting interactive Google Drive setup...
            echo Follow the prompts to configure your Google Drive access.
            echo.
            pause
            %RCLONE_CMD% config
        ) else if "!SETUP_CHOICE!"=="2" (
            set /p SA_FILE="Enter path to your service account JSON file: "
            if exist "!SA_FILE!" (
                echo Configuring with service account...
                %RCLONE_CMD% config create %REMOTE_NAME% drive service_account_file "!SA_FILE!"
            ) else (
                echo ERROR: Service account file not found: !SA_FILE!
                pause
                exit /b 1
            )
        ) else if "!SETUP_CHOICE!"=="3" (
            set /p CONF_FILE="Enter path to your rclone.conf file: "
            if exist "!CONF_FILE!" (
                echo Copying configuration file...
                if not exist "%USERPROFILE%\AppData\Roaming\rclone" mkdir "%USERPROFILE%\AppData\Roaming\rclone"
                copy "!CONF_FILE!" "%USERPROFILE%\AppData\Roaming\rclone\rclone.conf"
            ) else (
                echo ERROR: Configuration file not found: !CONF_FILE!
                pause
                exit /b 1
            )
        ) else if "!SETUP_CHOICE!"=="4" (
            echo Skipping configuration. You can configure later with:
            echo %RCLONE_CMD% config
            echo.
            echo For now, the script will exit. Run it again after configuration.
            pause
            exit /b 0
        ) else (
            echo Invalid choice. Please run the script again.
            pause
            exit /b 1
        )
    )
) else (
    echo ✓ Remote '%REMOTE_NAME%' is configured
)

REM ============================================================================
REM Final checks and mount
REM ============================================================================
echo.
echo Performing final checks...

REM Check if drive letter is already in use
if exist "%DRIVE_LETTER%" (
    echo WARNING: Drive %DRIVE_LETTER% is already in use!
    set /p CONTINUE="Do you want to continue anyway? (y/N): "
    if /i "!CONTINUE!" neq "y" (
        echo Aborted by user.
        pause
        exit /b 1
    )
)

REM Test connection to Google Drive
echo Testing connection to Google Drive...
%RCLONE_CMD% lsd %REMOTE_NAME%: --max-depth 1 >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Cannot connect to Google Drive remote '%REMOTE_NAME%'!
    echo Please check your internet connection and remote configuration.
    echo You can test manually with: %RCLONE_CMD% lsd %REMOTE_NAME%:
    pause
    exit /b 1
)
echo ✓ Connection test successful!

REM Create mount command
set MOUNT_CMD=%RCLONE_CMD% mount %REMOTE_NAME%: %DRIVE_LETTER% --vfs-cache-mode %VFS_CACHE_MODE% --log-file "%LOG_FILE%" --log-level %LOG_LEVEL%

REM Add authentication options if specified
if defined SERVICE_ACCOUNT_FILE (
    if exist "%SERVICE_ACCOUNT_FILE%" (
        set MOUNT_CMD=!MOUNT_CMD! --drive-service-account-file "%SERVICE_ACCOUNT_FILE%"
        echo ✓ Using service account file: %SERVICE_ACCOUNT_FILE%
    ) else (
        echo ❌ WARNING: Service account file not found: %SERVICE_ACCOUNT_FILE%
    )
)

REM Add additional flags if specified
if defined ADDITIONAL_FLAGS (
    set MOUNT_CMD=!MOUNT_CMD! %ADDITIONAL_FLAGS%
)

echo.
echo ============================================================================
echo All dependencies installed and configured!
echo Starting Google Drive mount...
echo Command: !MOUNT_CMD!
echo.
echo Press Ctrl+C to unmount and exit
echo ============================================================================

REM Start the mount (this will block until interrupted)
!MOUNT_CMD!

REM This section runs when the mount is interrupted
echo.
echo ============================================================================
echo Google Drive has been unmounted.
echo Check the log file for details: %LOG_FILE%
echo ============================================================================

REM Cleanup temp directory
if exist "%TEMP_DIR%" (
    echo Cleaning up temporary files...
    rmdir /s /q "%TEMP_DIR%" 2>nul
)

pause
