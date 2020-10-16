<#
.SYNOPSIS
    Script for deploying SQL Server maintenance scripts across environments

.EXAMPLE
    # for zone 1 environments
    .\Deploy-MaintenanceScripts.ps1 -DeploySecure $false

    # for zone 2 environments
    .\Deploy-MaintenanceScripts.ps1 -DeploySecure $true
#>

[CmdletBinding()] #See http://technet.microsoft.com/en-us/library/hh847884(v=wps.620).aspx for CmdletBinding common parameters
param(
    [parameter(Mandatory = $true)]
    [bool]$DeploySecure = $false,
    [parameter(Mandatory = $false)]
    [string]$ServerGroup
)

$Config = Get-Content .\Config.json | ConvertFrom-Json 

if ($DeploySecure -eq $false) {
    $Servers = $Config.servers | Where-Object {$_.type -ne "zone2_servers"}
    Write-Host "Deploying to non-zone 2 environments."
}
else {
    $Servers = $Config.servers | Where-Object {$_.type -eq "zone2_servers"}
    Write-Host "Deploying to zone 2 environments."
}

if ($ServerGroup){
    $Servers = $Config.servers | Where-Object {$_.type -eq $ServerGroup}
    Write-Host "Deploying servers to $ServerGroup"
}

$ScriptDirectory = $Config.ScriptDirectory

If(-not (Test-Path $ScriptDirectory)){
    Write-Error "$ScriptDirectory cannot be accessed!" -ErrorAction Stop
}

$scripts = Get-ChildItem $ScriptDirectory | Where-Object {$_.Extension -eq ".sql"}
$script_count = (Get-ChildItem $ScriptDirectory | Measure-Object).Count
$str_script = if($script_count -eq 1) {'script'} else {'scripts'}

Write-Host "Attempting to deploy $script_count $str_script to each server."

foreach ($server in $Servers) {
    Write-Host "Deploying to" $server.name

    foreach ($script in $scripts) {
        Write-Host "Installing" $script 
        Invoke-Sqlcmd -ServerInstance $server.Name -InputFile $script.FullName -DisableVariables

    }
}