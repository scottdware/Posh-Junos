$modulePath = "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules"
$poshSSH = "$($modulePath)\Posh-SSH"
$client = New-Object System.Net.WebClient

if (!(Test-Path -Path $poshSSH)) {
    Write-Warning "Looks like you don't have 'Posh-SSH' installed...installing it now."
    $client.DownloadString('https://gist.github.com/darkoperator/6152630/raw/c67de4f7cd780ba367cccbc2593f38d18ce6df89/instposhsshdev')
}

if (Test-Path -Path "$($modulePath)\Posh-Junos") {
    $sourceManifest = 'https://raw.githubusercontent.com/scottdware/Posh-Junos/master/Posh-Junos.psd1'
    $sourcePSM1 = 'https://raw.githubusercontent.com/scottdware/Posh-Junos/master/Posh-Junos.psm1'
    $destination = "$($modulePath)\Posh-Junos"
    
    if (Test-Path -Path $destination) {
        $client.DownloadFile($sourceManifest, "$($destination)\Posh-Junos.psd1")
        $client.DownloadFile($sourcePSM1, "$($destination)\Posh-Junos.psm1")
    }
    
    else {
        New-Item -Path $destination -ItemType directory -Force | Out-Null
        $client.DownloadFile($sourceManifest, "$($destination)\Posh-Junos.psd1")
        $client.DownloadFile($sourcePSM1, "$($destination)\Posh-Junos.psm1")
    }
}

Import-Module Posh-Junos
Write-Host -Foreground Green 'Module Posh-Junos has been successfully installed.'
Get-Command -Module Posh-Junos