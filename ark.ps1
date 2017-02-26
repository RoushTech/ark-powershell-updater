$map = "TheIsland"
$rconPort=32330
$settings = @(
    "SessionName=ServerName",
    "QueryPort=27015",
    "Port=7777",
    "SetCheatPlayer=True",
    "RCONEnabled=True",
    "RCONPort=$rconPort",
    "MaxPlayers=127"
    "ServerAdminPassword=Password",
    "AllowThirdPersonPlayer=True",
    "ShowMapPlayerLocation=True"
)

$steamcmdFolder="C:\Ark"
$arksurvivalFolder="C:\Ark\steamapps\common\ARK Survival Evolved Dedicated Server"
$arksurvivalSteamScript="update_ark.txt"
$rconIP="127.0.0.1"
$rconPassword="rconpassword"
$mcrconExec="C:\ARK-Scripts\mcrcon.exe"
$steamAppID="376030"
$clearCache=1

$settingsString = [string]::Join("?", $settings)
$arkSurvivalStartArguments= "$($map)?$($settingsString)?listen"
$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
$dataPath = $scriptPath+"\data"
$steamcmdExec = $steamcmdFolder+"\steamcmd.exe"
$steamcmdCache = $steamcmdFolder+"\appcache"
$latestAppInfo = $dataPath+"\latestappinfo.json"
$updateinprogress = $arksurvivalFolder+"\updateinprogress.dat"
$latestAvailableUpdate = $dataPath+"\latestavailableupdate.txt"
$latestInstalledUpdate = $dataPath+"\latestinstalledupdate.txt"

If (!(Test-Path $steamcmdExec)) {
    Write-Host "$steamcmdExec not found, make sure `$steamcmdFolder is set to the right path"
    Exit 1
}

If(!(Test-Path $mcrconExec)) {
    Write-Host "$mcrconExec not found, make sure `$mcrconExec is pointed at where mcrcon.exe is installed"
    Exit 1
}

function rcon($command) {
    iex "$mcrconExec -c -H $rconIP -P $rconPort -p $rconPassword `"$command`""
}

If (Test-Path $updateinprogress) {
    Write-Host Update is already in progress
    Exit 0
}

$pidARK = (Wmic process where "Commandline like '%$rconPort%' and Name='ShooterGameServer.exe'" get ProcessId | findstr /r "[1-9][0-9]")

Write-Host "Derp"
Exit 0

Get-Date | Out-File $updateinprogress
Write-Host Creating data Directory
New-Item -Force -ItemType directory -Path $dataPath
If ($clearCache) {
    Write-Host Removing Cache Folder
    Remove-Item $steamcmdCache -Force -Recurse
}
Write-Host Checking for an update
& $steamcmdExec +login anonymous +app_info_update 1 +app_info_print $steamAppID +app_info_print $steamAppID +quit | Out-File $latestAppInfo
Get-Content $latestAppInfo -RAW | Select-String -pattern '(?m)"public"\s*\{\s*"buildid"\s*"\d{6,}"' -AllMatches | %{$_.matches[0].value} | Select-String -pattern '\d{6,}' -AllMatches | %{$_.matches}  | %{$_.value} | Out-File $latestAvailableUpdate
If (Test-Path $latestInstalledUpdate) {
    $installedVersion = Get-Content $latestInstalledUpdate
} Else {
    $installedVersion = 0
}
$availableVersion = Get-Content $latestAvailableUpdate
if ($installedVersion -eq $availableVersion) {
    Remove-Item $updateinprogress -Force
    Exit 0
}

rcon "broadcast New update available, server is restarting in 10 minutes!"
Start-Sleep -s 300
rcon "broadcast New update available, server is restarting in 5 minutes!"
Start-Sleep -s 240
rcon "broadcast New update available, server is restarting in 10 minutes!"
Start-Sleep -s 60
rcon "broadcast New update available, server is restarting!"
rcon "saveworld"
Start-Sleep -s 10
iex "taskkill /PID $pidARK"
Start-Sleep -s 20
iex "$steamcmdExec +runscript $arksurvivalSteamScript"
iex "$arksurvivalFolder"\ShooterGame\Binaries\Win64\ShooterGameServer.exe" $arkSurvivalStartArguments -nosteamclient -game -lowmemory -nosound -sm4 -server -log"
$availableVersion | Out-File $latestInstalledUpdate
Write-Host Update Done!
Remove-Item $updateinprogress -Force