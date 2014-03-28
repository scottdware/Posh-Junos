## Posh-Junos

Allows the interaction of Junos devices (Juniper Networks) using Powershell.

### Dependancies

You must have the [Posh-SSH][1] module by [darkoperator][2] installed in order for this
module to work correctly.

### Installation

- [Download][3] the module and place it in your `Modules` folder.
    - Your `Modules` folder can be found by issuing the command `$env:PSModulePath`.
- Import the module by issuing `Import-Module Posh-Junos` on the command line, 
or from within your Powershell profile.
    - Your profile can be found by issuing the command
`$profile`.
- To display all of the functions of this module, issue the `Get-Command -Module Posh-Junos`
command.

### Functions

- Invoke-JunosConfig
    - Allows you to configure Junos devices using a template-style method.

[1]: https://github.com/darkoperator/Posh-SSH "Posh-SSH"
[2]: https://github.com/darkoperator "darkoperator"
[3]: https://github.com/scottdware/Posh-Junos/releases
