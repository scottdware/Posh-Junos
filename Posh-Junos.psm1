function Get-Auth {
    <#
    .Synopsis
        Takes a username and password parameter and creates the PSCredential token the
        same way that issuing Get-Credential does.
    .Parameter User
        The username that you wish to authenticate with.
    .Parameter Password
        The password for the given username.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $User,
        
        [Parameter(Mandatory = $true)]
        $Password
    )
    
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $psCreds = New-Object System.Management.Automation.PSCredential($User, $securePassword)
    
    return $psCreds
}

function Log-Output {
    <#
    .Synopsis
        Logs output to a file if specified.
    .Parameter File
        The file that our logging will be redirected to.
    .Parameter Content
        Writes the given content to the file specified.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $File,
        
        [Parameter(Mandatory = $true)]
        $Content
    )
    
    Write-Output $Content >> (Resolve-Path $File)
}

function Invoke-JunosConfig {
    <#
    .Synopsis
        Configure Junos devices
    .Description
        Allows the configuration of Junos devices (Juniper Networks) using a template-based
        configuration format so that you can specify different values unique to each device,
        if you wish.
    .Parameter ConfigFile
        Specifies the text file that has the configuration template (commands) that you wish to deploy.
        Please make sure that your commands are in 'set' format.
    .Parameter DeviceCSV
        Specifies the .CSV file that has all of the devices, credentials, and configurable items
    .Parameter LogFile
        If specified, all logging will be sent to this file instead of to the console.
    .Example
        Invoke-JunosConfig -ConfigFile C:\Temp\commands.txt -DeviceCSV C:\Temp\devices.csv
    .Link
        https://github.com/scottdware/Junos-Config
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $ConfigFile,
        
        [Parameter(Mandatory = $true)]
        $DeviceCSV,
        
        [Parameter(Mandatory = $false)]
        $LogFile
    )
    
    $config = Get-Content (Resolve-Path $ConfigFile)
    $devices = Import-CSV (Resolve-Path $DeviceCSV)
    $headers = $devices[0].PSObject.Properties | Select-Object Name
    
    if ($LogFile) {
        if (Test-Path $LogFile) {
            $ans = Read-Host 'Log file exists. Do you wish to overwrite? [y/n]'
            if ($ans -eq "y") {
                Remove-Item -Path $LogFile -ErrorAction 'SilentlyContinue'
                New-Item -Path $LogFile -ItemType file | Out-Null
            }
        }
        
        else {
            New-Item -Path $LogFile -ItemType file | Out-Null
        }
    }
    
    ForEach ($row in $devices) {
        $device = $row.PSObject.Properties.Value[0]
        $user = $row.PSObject.Properties.Value[1]
        $pass = $row.PSObject.Properties.Value[2]
        $creds = Get-Auth -User $user -Password $pass
        # $Timestamp = Get-Date -format "MM/dd/yyyy H:mm:ss"
        
        if ($LogFile) {
            Log-Output -File $LogFile -Content "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] Starting configuration on $Device..."
        }
        
        else {
            Write-Output "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] Starting configuration on $Device..."
        }
        
        try {
            $conn = New-SSHSession -ComputerName $device -Credential $creds -AcceptKey $true
            $size = $headers.Count
            $commands = @()
            $config | ForEach { $commands += $_ }
            $configuration = $commands -join "; "
            $results = Invoke-SSHCommand -Command $($configuration -f $row.PSObject.Properties.Value[3..$size]) -SSHSession $conn
            
            if ($LogFile) {
                Log-Output -File $LogFile -Content $results.Output
                Log-Output -File $LogFile -Content "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] Closing connection to $Device."
            }
            
            else {
                Write-Output $results.Output
                Write-Output "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] Closing connection to $Device."
            }
        }
        
        catch {
            if ($LogFile) {
                Log-Output -File $LogFile -Content "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] ERROR: Couldn't establish a connection to $Device."
                Log-Output -File $LogFile -Content "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] Please verify your credentials, and that the device is reachable."
            }
            
            else {
                Write-Warning "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] ERROR: Couldn't establish a connection to $Device."
                Write-Warning "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] Please verify your credentials, and that the device is reachable."
            }
        }
        
        finally {
            Remove-SSHSession -SSHSession $conn | Out-Null
        }
    }
}

Export-ModuleMember -Function Invoke-JunosConfig