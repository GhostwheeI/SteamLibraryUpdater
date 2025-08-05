@ECHO OFF
SETLOCAL EnableDelayedExpansion

SET RETVALUE=-1

IF "%1"=="" (
    ECHO ERROR: Please provide Steam App ID as first parameter
    GOTO END
)

IF "%2"=="" (
    ECHO ERROR: Please provide app directory as second parameter - likely within steamapps\common
    GOTO END
)

SET APP_INSTALL_DIR=%2\

IF NOT EXIST !APP_INSTALL_DIR! (
    ECHO ERROR: Install directory not found: !APP_INSTALL_DIR! 
    GOTO END
)

SET STEAMCMD=%~dp0\steamcmd\steamcmd.exe

IF NOT EXIST !STEAMCMD! (
    ECHO Expected: steamcmd located in !STEAMCMD!
    GOTO END
)

SET APPID=%1
SET APPINFO_DIR=%~dp0\appinfo
SET APPINFO_FILE=!APPINFO_DIR!\!APPID!
SET APPINFO_FILE_NEW=!APPINFO_FILE!-new

IF NOT EXIST !APPINFO_DIR!\ MKDIR !APPINFO_DIR!

ECHO Checking for needed updates for game id !APPID!

CALL curl https://api.steamcmd.net/v1/info/!APPID! --silent --output !APPINFO_FILE_NEW!
IF !ERRORLEVEL! NEQ 0 (
    ECHO Error getting app info for game
    GOTO END
)

SET NEEDS_UPDATE=1
IF EXIST !APPINFO_FILE! (
    CALL FC !APPINFO_FILE! !APPINFO_FILE_NEW! > NUL
    IF !ERRORLEVEL! EQU 0 SET NEEDS_UPDATE=0
)

IF !NEEDS_UPDATE! NEQ 0 (
    ECHO Update required, installing to !APP_INSTALL_DIR!
    CALL !STEAMCMD! +force_install_dir !APP_INSTALL_DIR! +login anonymous +app_update !APPID! validate +quit 
    IF !ERRORLEVEL! NEQ 0 (
        ECHO Error updating app via steamcmd
        GOTO END
    )
    
    MOVE !APPINFO_FILE_NEW! !APPINFO_FILE! > NUL

    ECHO Version out-of-date, returning 1
    SET RETVALUE=1
    GOTO END
) ELSE (
    ECHO Version up-to-date, returning 0
    DEL !APPINFO_FILE_NEW!
    SET RETVALUE=0
    GOTO END
)

:END

EXIT /B !RETVALUE!