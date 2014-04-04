$modulePath = "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules"
$poshSSH = "$($modulePath)\Posh-SSH"
$sourcePSM1 = 'https://raw.githubusercontent.com/scottdware/Posh-Junos/master/Posh-Junos.psm1'
$destination = "$($modulePath)\Posh-Junos"
$client = New-Object System.Net.WebClient

if (!(Test-Path -Path $poshSSH)) {
    Write-Warning "Looks like you don't have 'Posh-SSH' installed!"
    Write-Warning "Please visit https://github.com/darkoperator/Posh-SSH to install it first!"
    return
}

if (Test-Path -Path $destination) {
    Write-Warning "'Posh-Junos' already installed. Updating..."
    
    Remove-Item -Force $destination -Recurse | Out-Null
    Start-Sleep -Seconds 2
    New-Item -Path $destination -ItemType Directory -Force | Out-Null
    Start-Sleep -Seconds 1
    
    $client.DownloadFile($sourcePSM1, "$($destination)\Posh-Junos.psm1")
    
    Write-Host -Fore Green 'Module Posh-Junos has been successfully updated.'
}

else {
    New-Item -Path $destination -ItemType Directory -Force | Out-Null
    Start-Sleep -Seconds 1
    
    $client.DownloadFile($sourcePSM1, "$($destination)\Posh-Junos.psm1")
    
    Write-Host -Fore Green 'Module Posh-Junos has been successfully installed.'
}

Import-Module Posh-Junos
Get-Command -Module Posh-Junos