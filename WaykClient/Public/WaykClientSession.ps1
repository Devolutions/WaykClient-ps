
function Get-WaykPSBasePath
{
    [CmdletBinding()]
    param(
    )

    # TODO: improve detection of path containing fake ssh executable

    $WaykClient = Get-WaykClientCommand
    $(Get-Item $WaykClient).Directory.FullName
}

function Enter-WaykPSEnvironment
{
    [CmdletBinding()]
    param(
    )

    # Add fake ssh to beginning of PATH environment variable if not present

    if ($PSEdition -eq 'Desktop') {
        throw "Wayk PowerShell remoting requires PowerShell 7 or later"
    }

    $WaykBasePath = Get-WaykPSBasePath

    $EnvPath = $Env:PATH
    $EnvPaths = $Env:PATH -Split $([IO.Path]::PathSeparator)

    if ($EnvPaths[0] -ne $WaykBasePath) {
        $Env:Path = "${WaykBasePath}$([IO.Path]::PathSeparator)$EnvPath"
    }
}

function Connect-WaykPSSession
{
    param(
        [Parameter(Mandatory=$true)]
        [String] $HostName,
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential
    )

    # Call Wayk Client to initiate the connect and return JetUrl

    $UserName = $Credential.UserName
    $Password = $Credential.GetNetworkCredential().Password

    $WaykClient = Get-WaykClientCommand

    $CommandInput = [PSCustomObject]@{
        Hostname = $HostName
        Username = $UserName
        Password = $Password
    } | ConvertTo-Json | Out-String

    Write-Host "Input: ${CommandOutput}"

    $CommandOutput = $CommandInput | & "$WaykClient" 'pwsh' '-'

    Write-Host "Output: ${CommandOutput}"

    $CommandOutput = $CommandOutput | ConvertFrom-Json

    if (-Not $CommandOutput.Success) {
        throw "Failed to connect to ${HostName} with user ${UserName}"
    }

    $JetUrl = $CommandOutput.JetUrl
    $Env:JET_URL = $JetUrl

    return $CommandOutput
}

function New-WaykPSSession
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $HostName,
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential
    )

    Enter-WaykPSEnvironment
    Connect-WaykPSSession -HostName:$HostName -Credential:$Credential
    New-PSSession -UserName:$UserName -HostName:$HostName -SSHTransport
}

function Enter-WaykPSSession
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $HostName,
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential
    )

    Enter-WaykPSEnvironment
    Connect-WaykPSSession -HostName:$HostName -Credential:$Credential
    Enter-PSSession -UserName:$UserName -HostName:$HostName -SSHTransport
}
