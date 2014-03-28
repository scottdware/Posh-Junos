## Posh-Junos

Allows the interaction of Junos devices (Juniper Networks) using Powershell.

**Why Powershell?**

There are a lot of good tools already out there to interact with Junos devices using
[Python][5], [Ruby][6], etc. I basically wanted to add another one into the fray for those who
might be heavy Windows users, like myself. The Python and Ruby modules can do a lot, more
than this one can at the moment. But despite this module being so new, my goal is to keep
adding functionality to it so it becomes an every day addition to those who love Junos!

Another reason why I chose to use Powershell was the majority of Windows users have Powershell
already installed...so there's no need to install another programming language or other
other binaries.

### Dependancies

You must have the [Posh-SSH][1] module by [darkoperator][2] installed in order for this
module to work correctly. If you do not, then please visit the above link and install it.

### Installation

For automatic installation (preferred), copy the following command and paste it into your Powershell console

`iex (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/scottdware/Posh-Junos/master/install.ps1")`

**Manual Installation**

- [Download][3] the module and unzip it to a folder named `Posh-Junos` in your `Modules` folder.
    - Your `Modules` folder can be found by issuing the command `$env:PSModulePath`.
- Import the module by issuing `Import-Module Posh-Junos` on the command line, 
or from within your Powershell profile.
    - Your profile can be found by issuing the command
`$profile`.
- To display all of the functions of this module, issue the `Get-Command -Module Posh-Junos`
command.

### Help, Documentation

Please visit the [Wiki][4] for more detailed documentation.

[1]: https://github.com/darkoperator/Posh-SSH "Posh-SSH"
[2]: https://github.com/darkoperator "darkoperator"
[3]: https://github.com/scottdware/Posh-Junos/archive/master.zip
[4]: https://github.com/scottdware/Posh-Junos/wiki
[5]: https://techwiki.juniper.net/Automation_Scripting/Junos_OS_PyEZ
[6]: https://techwiki.juniper.net/Automation_Scripting/Scripts_by_Languages/Ruby