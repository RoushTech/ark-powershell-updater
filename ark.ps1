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

function startArk {
    #iex "`"'$arksurvivalFolder\ShooterGame\Binaries\Win64\ShooterGameServer.exe' $arkSurvivalStartArguments -nosteamclient -game -lowmemory -nosound -sm4 -server -log`""
    & $arksurvivalFolder"\ShooterGame\Binaries\Win64\ShooterGameServer.exe" $arkSurvivalStartArguments -nosteamclient -game -lowmemory -nosound -sm4 -server -log
}

If (Test-Path $updateinprogress) {
    Write-Host Update is already in progress
    Exit 0
}

$processes = @(Get-WmiObject Win32_Process -Filter "name = 'ShooterGameServer.exe'" | where { $_.CommandLine -like "*$rconPort*" })
$pidARK = $null
If($processes.length -gt 0) {
    Write-Host "Ark process found."
    $pidARK = $processes[0].ProcessId
} else {
    Write-Host "No Ark process found, starting after patch check..."
}

Get-Date | Out-File $updateinprogress
Write-Host "Creating data Directory"
New-Item -Force -ItemType directory -Path $dataPath | Out-Null
If ($clearCache) {
    Write-Host Removing Cache Folder
    Remove-Item $steamcmdCache -Force -Recurse
}

Write-Host Checking for an update
iex "$steamcmdExec +login anonymous +app_info_update 1 +app_info_print $steamAppID +app_info_print $steamAppID +quit" | Out-File $latestAppInfo
Get-Content $latestAppInfo -RAW | Select-String -pattern '(?m)"public"\s*\{\s*"buildid"\s*"\d{6,}"' -AllMatches | %{$_.matches[0].value} | Select-String -pattern '\d{6,}' -AllMatches | %{$_.matches}  | %{$_.value} | Out-File $latestAvailableUpdate
If (Test-Path $latestInstalledUpdate) {
    $installedVersion = Get-Content $latestInstalledUpdate
} Else {
    $installedVersion = 0
}

$availableVersion = Get-Content $latestAvailableUpdate
if ($installedVersion -eq $availableVersion) {
    Remove-Item $updateinprogress -Force
    if($pidARK -eq $null) {
        startArk
    }

    Exit 0
}

if($pidARK -ne $null) {
    rcon "broadcast New update available, server is restarting in 10 minutes!"
    Start-Sleep -s 300
    rcon "broadcast New update available, server is restarting in 5 minutes!"
    Start-Sleep -s 240
    rcon "broadcast New update available, server is restarting in 10 minutes!"
    Start-Sleep -s 60
    rcon "broadcast New update available, server is restarting!"
    rcon "saveworld"
    Start-Sleep -s 10
    Stop-Process -id $pidARK -Force
    Start-Sleep -s 20
}

iex "$steamcmdExec +runscript $arksurvivalSteamScript"
startAr
$availableVersion | Out-File $latestInstalledUpdate
Write-Host Update Done!
Remove-Item $updateinprogress -Force