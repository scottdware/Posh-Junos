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
    
    Param(
        [Parameter(Mandatory = $True)]
        $User,
        
        [Parameter(Mandatory = $True)]
        $Password
    )
    
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $PSCreds = New-Object System.Management.Automation.PSCredential($User, $SecurePassword)
    
    return $PSCreds
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
    
    Param(
        [Parameter(Mandatory = $True)]
        $File,
        
        [Parameter(Mandatory = $True)]
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
    .Link
        https://github.com/scottdware/Junos-Config
    #>
    
    Param(
        [Parameter(Mandatory = $True)]
        $ConfigFile,
        
        [Parameter(Mandatory = $True)]
        $DeviceCSV,
        
        [Parameter(Mandatory = $False)]
        $LogFile
    )
    
    $Config = Get-Content (Resolve-Path $ConfigFile)
    $Devices = Import-CSV (Resolve-Path $DeviceCSV)
    $Headers = $Devices[0].PSObject.Properties | Select-Object Name
    
    if ($LogFile) {
        if (Test-Path $LogFile) {
            $Ans = Read-Host "Log file already exists...do you want to delete the old one?"
            if ($Ans -eq "y") {
                Remove-Item -Path $LogFile -Force
                New-Item -Path $LogFile -ItemType file | Out-Null
            }
        }
        
        else {
            New-Item -Path $LogFile -ItemType file | Out-Null
        }
    }
    
    ForEach ($Row in $Devices) {
        $Device = $Row.PSObject.Properties.Value[0]
        $User = $Row.PSObject.Properties.Value[1]
        $Pass = $Row.PSObject.Properties.Value[2]
        $Creds = Get-Auth -User $User -Password $Pass
        $Timestamp = Get-Date -format "MM/dd/yyyy H:mm:ss"
        
        if ($LogFile) {
            Log-Output -File $LogFile -Content "[$($Timestamp)] Starting configuration on $Device..."
        }
        
        else {
            Write-Output "[$($Timestamp)] Starting configuration on $Device..."
        }
        
        try {
            $Conn = New-SSHSession -ComputerName $Device -Credential $Creds
            $Size = $Headers.Count
            $Commands = @()
            $Config -f $Row.PSObject.Properties.Value[3..$Size] | ForEach { $Commands += $_ }
            $results = Invoke-SSHCommand -Command $($Commands -join "; ") -SSHSession $Conn
            
            if ($LogFile) {
                Log-Output -File $LogFile -Content $results.Output
                Log-Output -File $LogFile -Content "[$($Timestamp)] Closing connection to $Device."
            }
            
            else {
                Write-Output $results.Output
                Write-Output "[$($Timestamp)] Closing connection to $Device."
            }
        }
        
        catch {
            if ($LogFile) {
                Log-Output -File $LogFile -Content "[$($Timestamp)] Couldn't establish a connection to $Device."
                Log-Output -File $LogFile -Content "[$($Timestamp)] Please verify your credentials, and that the device is reachable."
            }
            
            else {
                Write-Host "[$($Timestamp)] Couldn't establish a connection to $Device."
                Write-Host "[$($Timestamp)] Please verify your credentials, and that the device is reachable."
            }
        }
        
        finally {
            Remove-SSHSession -SSHSession $Conn | Out-Null
        }
    }
}

Export-ModuleMember -Function Invoke-JunosConfig