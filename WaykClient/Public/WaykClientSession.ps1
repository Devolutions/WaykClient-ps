
function Get-WaykPSRemotingPath
{
    [CmdletBinding()]
    param(
    )

    if ($IsWindows) {
        $WaykClient = Get-WaykClientCommand
        $WaykBinPath = $(Get-Item $WaykClient).Directory.FullName
        $PSRemotingPath = Join-Path $WaykBinPath 'psremoting'
    } elseif ($IsMacOS) {
        $WaykBinPath = "/Applications/WaykClient.app/Contents/MacOS"
        $PSRemotingPath = Join-Path $WaykBinPath 'psremoting'
    } elseif ($IsLinux) {
        $WaykLibPath = "/usr/lib"
        $PSRemotingPath = Join-Path $WaykLibPath 'psremoting'
    }

    $PSRemotingPath
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

    $PSRemotingPath = Get-WaykPSRemotingPath

    if (-Not (Test-Path $PSRemotingPath -PathType 'Container')) {
        throw "Could not find required Wayk PSRemoting directory: `"$PSRemotingPath`""
    }

    $EnvPath = $Env:PATH
    $EnvPaths = $Env:PATH -Split $([IO.Path]::PathSeparator)

    if ($EnvPaths[0] -ne $PSRemotingPath) {
        $Env:PATH = "${PSRemotingPath}$([IO.Path]::PathSeparator)$EnvPath"
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

    Enter-WaykPSEnvironment

    $UserName = $Credential.UserName
    $Password = $Credential.GetNetworkCredential().Password

    $WaykClient = Get-WaykClientCommand

    $CommandInput = [PSCustomObject]@{
        Hostname = $HostName
        Username = $UserName
        Password = $Password
    } | ConvertTo-Json -Compress | Out-String

    $CommandOutput = $CommandInput | & "$WaykClient" 'pwsh' '-' 2>/dev/null
    $CommandOutput = $CommandOutput | ConvertFrom-Json

    if (-Not $CommandOutput.Success) {
        throw "Failed to connect to ${HostName} with user ${UserName} with error $($CommandOutput.Error)"
    }

    $JetUrl = $CommandOutput.JetUrl
    $Env:JETSOCAT_ARGS = "connect $JetUrl"

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

    $Result = Connect-WaykPSSession -HostName:$HostName -Credential:$Credential
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

    $Result = Connect-WaykPSSession -HostName:$HostName -Credential:$Credential
    Enter-PSSession -UserName:$UserName -HostName:$HostName -SSHTransport
}
