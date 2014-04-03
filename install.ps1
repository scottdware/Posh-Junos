$modulePath = "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules"
$poshSSH = "$($modulePath)\Posh-SSH"
$sourceManifest = 'https://raw.githubusercontent.com/scottdware/Posh-Junos/master/Posh-Junos.psd1'
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
    
    $client.DownloadFile($sourceManifest, "$($destination)\Posh-Junos.psd1")
    $client.DownloadFile($sourcePSM1, "$($destination)\Posh-Junos.psm1")
}

else {
    New-Item -Path $destination -ItemType directory -Force | Out-Null
    $client.DownloadFile($sourceManifest, "$($destination)\Posh-Junos.psd1")
    $client.DownloadFile($sourcePSM1, "$($destination)\Posh-Junos.psm1")
}

Import-Module Posh-Junos
Write-Host -Fore Green 'Module Posh-Junos has been successfully installed.'
Get-Command -Module Posh-Junos