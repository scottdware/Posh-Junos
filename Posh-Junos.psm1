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
        [string] $User,

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
        [string] $File,

        [Parameter(Mandatory = $true)]
        [string] $Content
    )

    Write-Output $Content >> (Resolve-Path $File)
}

function Timestamp {
    Get-Date -format "MM/dd/yyyy H:mm:ss"
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
    .Parameter DeviceList
        Specifies the .CSV file that has all of the devices, credentials, and configurable items if
        necessary.
    .Parameter File
        If specified, all logging will be sent to the file specified here, instead of to the default
        location (current working directory where the script is run, named "junos-config.log").
    .Example
        Invoke-JunosConfig -ConfigFile C:\Temp\commands.txt -DeviceList C:\Temp\devices.csv
    .Link
        https://github.com/scottdware/Posh-Junos/wiki/Functions#invoke-junosconfig
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ConfigFile,

        [Parameter(Mandatory = $true)]
        [string] $DeviceList,

        [Parameter(Mandatory = $false)]
        [string] $File
    )

    $config = Get-Content (Resolve-Path $ConfigFile)
    $devices = Import-CSV (Resolve-Path $DeviceList)
    $headers = $devices[0].PSObject.Properties | Select-Object Name
    $totalDevices = $devices | Measure-Object
    $current = 0
    $errors = 0

    if ($File) {
        $logfile = $File
    }

    else {
        $logfile = "$(Get-Location)\junos-config.log"
    }

    if (Test-Path $logfile) {
        $ans = Read-Host 'Log file exists. Do you wish to overwrite? [y/n]'
        if ($ans -eq "y") {
            Remove-Item -Path $logfile -ErrorAction 'SilentlyContinue'
            New-Item -Path $logfile -ItemType file | Out-Null
        }
    }

    else {
        New-Item -Path $logfile -ItemType file | Out-Null
    }

    Write-Output "`nStarting configuration on a total of $($totalDevices.Count) devices."
    Write-Output "Results will be logged to '$logfile'`n"

    foreach ($row in $devices) {
        $current += 1
        $device = $row.PSObject.Properties.Value[0]
        $user = $row.PSObject.Properties.Value[1]
        $pass = $row.PSObject.Properties.Value[2]

        if (!($user) -or !($pass)) {
            Log-Output -File $logfile -Content "[$(Timestamp)] No username or password was specified for $device. Please check your .CSV file!"

            continue
        }

        $creds = Get-Auth -User $user -Password $pass
        $percent = [Math]::Round($current / $totalDevices.Count * 100)
        Write-Progress -Activity 'Configuration in progress...' -Status "$current of $($totalDevices.Count) devices ($percent%):" -PercentComplete $percent

        Log-Output -File $logfile -Content "[$(Timestamp)] Starting configuration on $Device..."

        try {
            $conn = New-SSHSession -ComputerName $device -Credential $creds -AcceptKey $true
            $size = $headers.Count
            $commands = @()
            $config | foreach { $commands += $_ }
            $configuration = $commands -join "; "

            if ($size -eq 3) {
                $results = Invoke-SSHCommand -Command $($configuration) -SSHSession $conn
            }

            else {
                $results = Invoke-SSHCommand -Command $($configuration -f $row.PSObject.Properties.Value[3..$size]) -SSHSession $conn
            }

            Log-Output -File $logfile -Content $results.Output.trim()
            Log-Output -File $logfile -Content "[$(Timestamp)] Closing connection to $Device.`n"
        }

        catch {
            $errors += 1

            Log-Output -File $logfile -Content "[$(Timestamp)] ERROR: Couldn't establish a connection to $Device."
            Log-Output -File $logfile -Content "[$(Timestamp)] Please verify your credentials, and that the device is reachable.`n"
        }

        finally {
            Remove-SSHSession -SSHSession $conn | Out-Null
        }
    }

    Write-Output "Configuration complete - $errors configuration errors!"

    if ($errors -gt 0) {
        Write-Output "Please check the log file '$($logfile)' to review these errors."
    }
}

function Invoke-JunosCommand {
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
        Invoke-JunosCommand -Device firewall-1.company.com -Command "show system users" -User admin
    .Example
        Invoke-JunosCommand -Device firewall-1.company.com -Command "show system users; show system storage" -User admin
    .Example
        Invoke-JunosCommand -Device firewall-1.company.com -Command C:\Temp\commands.txt -User admin
    .Link
        https://github.com/scottdware/Posh-Junos/wiki/Functions#invoke-junoscommand
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

    if ((Test-Path $Device -PathType Leaf -ErrorAction 'SilentlyContinue')) {
        $hosts = @()
        Get-Content (Resolve-Path $Device) | foreach { $hosts += $_ }
        
        foreach ($host in $hosts) {
            try {
                $conn = New-SSHSession -ComputerName $host -Credential $creds -AcceptKey $true

                if ((Test-Path $Command -PathType Leaf -ErrorAction 'SilentlyContinue')) {
                    $commands = @()
                    Get-Content (Resolve-Path $Command) | foreach { $commands += $_ }
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

                    Write-Output "`n$host`n===============`n" >> (Resolve-Path $File)
                    Write-Output $results.Output.trim() >> (Resolve-Path $File)
                    Write-Output "" >> (Resolve-Path $File)
                }

                else {
                    Write-Output "`n$host`n===============`n"
                    Write-Output $results.Output.trim()
                    Write-Output ""
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
    }
    
    else {
        try {
            $conn = New-SSHSession -ComputerName $Device -Credential $creds -AcceptKey $true

            if ((Test-Path $Command -PathType Leaf -ErrorAction 'SilentlyContinue')) {
                $commands = @()
                Get-Content (Resolve-Path $Command) | foreach { $commands += $_ }
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

                Write-Output "`n$Device`n===============`n" >> (Resolve-Path $File)
                Write-Output $results.Output.trim() >> (Resolve-Path $File)
                Write-Output "" >> (Resolve-Path $File)
            }

            else {
                Write-Output "`n$Device`n===============`n"
                Write-Output $results.Output.trim()
                Write-Output ""
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
}

function New-TrafficSelector {
    <#
    .Synopsis
        Generate traffic-selectors (multi proxy-ID) for SRX devices.
    .Description
        This function will allow you to create the necessary configuration to add multi proxy-ID
        support to your IPsec VPN tunnel. Juniper calls this "traffic-selectors."
    .Parameter Local
        Specify the local (your) IP addresses or subnets. Please include the subnet mask in CIDR
        notation, and separate multiple entries with a comma.
    .Parameter Remote
        Specify the remote end IP addresses or subnets. Please include the subnet mask in CIDR
        notation, and separate multiple entries with a comma.
    .Parameter VPN
        Specify the VPN that you want to add these traffic-selectors to. Must match the name
        you have defined under your IPsec VPN configuration.
    .Parameter File
        This will allow you to save your results to the given file.
    .Example
        New-TrafficSelector -Local 10.1.1.0/24, 192.168.1.25/32 -Remote 172.20.0.0/23 -VPN Some-Company
    .Link
        https://github.com/scottdware/Posh-Junos/wiki/Functions#New-TrafficSelector
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]] $Local,

        [Parameter(Mandatory = $true)]
        [string[]] $Remote,

        [Parameter(Mandatory = $true)]
        [string] $VPN,

        [Parameter(Mandatory = $false)]
        [string] $File
    )

    $Total = $Local.Count * $Remote.Count
    $Start = 1

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

        Log-Output -File $File -Content "configure"

        while ($Start -le $Total) {
            foreach ($localIP in $Local) {
                foreach ($remoteIP in $Remote) {
                    # $selector = "set security ipsec vpn $VPN traffic-selector $($localIP)_$($remoteIP) local-ip $localIP remote-ip $remoteIP"
                    $selector = "set security ipsec vpn $VPN traffic-selector TS$($Start) local-ip $localIP remote-ip $remoteIP"
                    Log-Output -File $File -Content $selector

                    $Start += 1
                }
            }
        }

        Log-Output -File $File -Content "commit and-quit"
    }

    else {
        Write-Output "-- Copy & Paste into SRX --`n"

        while ($Start -le $Total) {
            foreach ($localIP in $Local) {
                foreach ($remoteIP in $Remote) {
                    # Write-Output "set security ipsec vpn $VPN traffic-selector $($localIP)_$($remoteIP) local-ip $localIP remote-ip $remoteIP"
                    Write-Output "set security ipsec vpn $VPN traffic-selector TS$($Start) local-ip $localIP remote-ip $remoteIP"

                    $Start += 1
                }
            }
        }
    }
}

function Get-Junos {
    <#
    .Synopsis
        Get software information about the given Junos device.
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
        $results = Get-Junos -Device firewall-1.company.com -User admin -Password somepass
    .Link
        https://github.com/scottdware/Posh-Junos/wiki/Functions#get-junos
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
        $results = Invoke-SSHCommand -Command "show version | display xml" -SSHSession $conn
        [xml] $version = $results.Output
        $info = @{}

        if ($version.'rpc-reply'.'multi-routing-engine-results') {
            foreach ($node in $version.'rpc-reply'.'multi-routing-engine-results'.'multi-routing-engine-item') {
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
                $info.GetEnumerator() | Sort-Object Name | foreach {
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
            $hostname = $version.'rpc-reply'.'software-information'.'host-name'
            $model = $version.'rpc-reply'.'software-information'.'product-model'

            if ($model -imatch "srx") {
                $swType = $version.'rpc-reply'.'software-information'.'package-information'.name
                $swComment = $version.'rpc-reply'.'software-information'.'package-information'.comment
            }

            else {
                $swType = $version.'rpc-reply'.'software-information'.'package-information'[0].name
                $swComment = $version.'rpc-reply'.'software-information'.'package-information'[0].comment
            }

            $swComment -match "^.*\[(.*)\].*$" | Out-Null
            $swVer = $Matches[1]

            $info = @{
                "host-name" = $hostname;
                "model" = $model;
                "software-type" = $swType;
                "software-version" = $swVer;
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

Export-ModuleMember -Function Invoke-JunosConfig
Export-ModuleMember -Function Invoke-JunosCommand
Export-ModuleMember -Function New-TrafficSelector
Export-ModuleMember -Function Get-Junos
