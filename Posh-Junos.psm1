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
        [String[]] $User,
        
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
        [String[]] $File,
        
        [Parameter(Mandatory = $true)]
        [String[]] $Content
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
        https://github.com/scottdware/Posh-Junos/wiki
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String[]] $ConfigFile,
        
        [Parameter(Mandatory = $true)]
        [String[]] $DeviceCSV,
        
        [Parameter(Mandatory = $false)]
        [String[]] $LogFile
    )
    
    $config = Get-Content (Resolve-Path $ConfigFile)
    $devices = Import-CSV (Resolve-Path $DeviceCSV)
    $headers = $devices[0].PSObject.Properties | Select-Object Name
    $totalDevices = $devices.Count
    $current = 0
    $errors = 0
    
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
    
    Write-Output "`nStarting configuration on a total of $totalDevices devices."
    Write-Output "Please note that this might take a while, depending on"
    Write-Output "the number of devices you are configuring.`n"
    
    ForEach ($row in $devices) {
        $current += 1
        $device = $row.PSObject.Properties.Value[0]
        $user = $row.PSObject.Properties.Value[1]
        $pass = $row.PSObject.Properties.Value[2]
        
        if (!($user) -or !($pass)) {
            if ($LogFile) {
                Log-Output -File $LogFile -Content "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] No username or password was specified for $device. Please check your .CSV file!"
            }
            
            else {
                Write-Warning "[$(Get-Date -format 'MM/dd/yyyy H:mm:ss')] No username or password was specified for $device. Please check your .CSV file!"
            }
            
            continue
        }
        
        $creds = Get-Auth -User $user -Password $pass
        # $Timestamp = Get-Date -format "MM/dd/yyyy H:mm:ss"
        
        $percent = [Math]::Round($current / $totalDevices * 100)
        Write-Progress -Activity 'Configuration in progress...' -Status "$current of $totalDevices devices ($percent%):" -PercentComplete $percent
        
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
            $errors += 1
            
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
    
    Write-Output "Configuration complete - $errors configuration errors!"
    
    if ($errors -gt 0) {
        Write-Output "Please check the log file '$LogFile' to review these errors."
    }
}

function Invoke-RpcCommand {
    <#
    .Synopsis
        Execute RPC commands and return the results.
    .Description
        This function allows you to execute RPC commands, such as any "show" command.
    .Parameter Device
        The Junos device you wish to execute the command on.
    .Parameter Command
        The command that you want to execute. Please enclose in double quotes "". To execute
        multiple commands, separate them using a ; (see examples). You can also specify a file
        that has the commands you want to run (one per line). This is good for quick configuration
        of devices, also!
    .Parameter User
        The username you want to execute the command as.
    .Parameter Password
        The password for the username specified. If you omit this, you will be prompted for the
        password instead (more secure).
    .Parameter File
        This will allow you to save your results to the given file.
    .Example
        Invoke-RpcCommand -Device firewall-1.company.com -Command "show system users" -User admin
    .Example
        Invoke-RpcCommand -Device firewall-1.company.com -Command "show system users; show system storage" -User admin
    .Example
        Invoke-RpcCommand -Device firewall-1.company.com -Command C:\Temp\commands.txt -User admin
    .Link
        https://github.com/scottdware/Junos-Config
        https://github.com/scottdware/Posh-Junos/wiki
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Device,
        
        [Parameter(Mandatory = $true)]
        [string] $Command,
        
        [Parameter(Mandatory = $true)]
        [string] $User,
        
        [Parameter(Mandatory = $false)]
        [string] $Password,
        
        [Parameter(Mandatory = $false)]
        [string] $File
    )
    
    if (!($Password)) {
        $pass = Read-Host "Password" -AsSecureString
        $creds = New-Object System.Management.Automation.PSCredential($User, $pass)
    }
    
    else {
        $creds = Get-Auth -User $User -Password $Password
    }
    
    try {
        $conn = New-SSHSession -ComputerName $Device -Credential $creds -AcceptKey $true
        
        if ((Test-Path $Command -PathType Leaf -ErrorAction 'SilentlyContinue')) {
            $commands = @()
            Get-Content (Resolve-Path $Command) | ForEach { $commands += $_ }
            $results = Invoke-SSHCommand -Command $($commands -join "; ") -SSHSession $conn
        }
        
        else {
            $results = Invoke-SSHCommand -Command $($Command) -SSHSession $conn
        }
        
        if ($File) {
            if (Test-Path $File) {
                $ans = Read-Host 'Log file exists. Do you wish to overwrite? [y/n]'
                if ($ans -eq "y") {
                    Remove-Item -Path $File -ErrorAction 'SilentlyContinue'
                    New-Item -Path $File -ItemType file | Out-Null
                }
            }
            
            else {
                New-Item -Path $File -ItemType file | Out-Null
            }
            
            Write-Output "Executing command: '$Command'" >> (Resolve-Path $File)
            Write-Output $results.Output >> (Resolve-Path $File)
        }
        
        else {
            Write-Output $results.Output
        }
    }
    
    catch {
        Write-Warning "There was a problem connecting to $Device."
        Write-Warning "Please make sure your credentials are correct, and that the device is reachable."
    }
    
    finally {
        Remove-SSHSession -SSHSession $conn | Out-Null
    }
}

function Get-JunosFacts {
    <#
    .Synopsis
        Get basic information about the given Junos device.
    .Description
        This function will get such information as hostname, software version, software type,
        model, etc.
    .Parameter Device
        The Junos device you wish to query.
    .Parameter User
        The username you want to connect as.
    .Parameter Password
        The password for the username specified. If you omit this, you will be prompted for the
        password instead (more secure).
    .Parameter Display
        If this option is specified, the information is displayed to the console/screen. If omitted,
        then the information is best suited as being stored in a variable.
    .Example
        Get-JunosFacts -Device firewall-1.company.com -User admin -Display
    .Example
        $results = Get-JunosFacts -Device firewall-1.company.com -User admin -Password somepass
    .Link
        https://github.com/scottdware/Junos-Config
        https://github.com/scottdware/Posh-Junos/wiki
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Device,
        
        [Parameter(Mandatory = $true)]
        [string] $User,
        
        [Parameter(Mandatory = $false)]
        [string] $Password,
        
        [Parameter(Mandatory = $false)]
        [switch] $Display
    )

    if (!($Password)) {
        $pass = Read-Host "Password" -AsSecureString
        $creds = New-Object System.Management.Automation.PSCredential($User, $pass)
    }
    
    else {
        $creds = Get-Auth -User $User -Password $Password
    }
    
    try {
        $conn = New-SSHSession -ComputerName $Device -Credential $creds -AcceptKey $true
        $result = Invoke-SSHCommand -Command "show version | display xml" -SSHSession $conn
        [xml] $xml = $result.Output
        $info = @{}

        if ($xml.'rpc-reply'.'multi-routing-engine-results') {
            ForEach ($node in $xml.'rpc-reply'.'multi-routing-engine-results'.'multi-routing-engine-item') {
                $nodeName = $node.'re-name'
                $hostname = $node.'software-information'.'host-name'
                $model = $node.'software-information'.'product-model'

                if ($model -imatch "srx") {
                    $swType = $node.'software-information'.'package-information'.name
                    $swComment = $node.'software-information'.'package-information'.comment
                }
                
                else {
                    $swType = $node.'software-information'.'package-information'[0].name
                    $swComment = $node.'software-information'.'package-information'[0].comment        
                }
                
                $swComment -match "^.*\[(.*)\].*$" | Out-Null
                $swVer = $Matches[1]
               
                $nodeInfo = @{
                    "host-name" = $hostname;
                    "model" = $model;
                    "software-type" = $swType;
                    "software-version" = $swVer
                }
                
                $info.Add($nodeName, $nodeInfo)
            }
            
            if ($Display) {
                $info.GetEnumerator() | Sort-Object Name | ForEach {
                    Write-Output "RE: $($_.key)"
                    Write-Output "`tHostname: $($_.value['host-name'])"
                    Write-Output "`tModel: $($_.value['model'])"
                    Write-Output "`tSoftware Version: $($_.value['software-version'])"
                    Write-Output "`tSoftware Type: $($_.value['software-type'])"
                }
            }
            
            else {
                return $info
            }
        }

        else {
            $hostname = $xml.'rpc-reply'.'software-information'.'host-name'
            $model = $xml.'rpc-reply'.'software-information'.'product-model'
            
            if ($model -imatch "srx") {
                $swType = $xml.'rpc-reply'.'software-information'.'package-information'.name
                $swComment = $xml.'rpc-reply'.'software-information'.'package-information'.comment
            }
            
            else {
                $swType = $xml.'rpc-reply'.'software-information'.'package-information'[0].name
                $swComment = $xml.'rpc-reply'.'software-information'.'package-information'[0].comment        
            }

            $swComment -match "^.*\[(.*)\].*$" | Out-Null
            $swVer = $Matches[1]
            
            $info = @{
                "host-name" = $hostname;
                "model" = $model;
                "software-type" = $swType;
                "software-version" = $swVer
            }

            if ($Display) {
                Write-Output "Hostname: $($info['host-name'])"
                Write-Output "Model: $($info['model'])"
                Write-Output "Software Version: $($info['software-version'])"
                Write-Output "Software Type: $($info['software-type'])"
            }
            
            else {
                return $info
            }
        }
    }
    
    catch {
        Write-Warning "There was a problem connecting to $Device."
        Write-Warning "Please make sure your credentials are correct, and that the device is reachable."
    }
    
    finally {
        Remove-SSHSession -SSHSession $conn | Out-Null
    }
}

Export-ModuleMember -Function Invoke-JunosConfig, Invoke-RpcCommand, Get-JunosFacts