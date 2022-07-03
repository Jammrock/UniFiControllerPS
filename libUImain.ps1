#Requires -Version 7.1

<#

libUImain handles globals, defaults, and sessions.

#>


<#

Project rules:

- Encoding must be UTF-8 with BOM (utf8bom) for cross platform PowerShell compatibilty.
- Classes and Enums should be prefixed with UI.
- Classes and Enums should all be in libUIclasses to prevent import issues.
- Function nouns should be prefixed with Unifi.
- Only approved PowerShell naming conventions should be used.
    - https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.1

- PowerShell best pratcies should be followed.
    - https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines?view=powershell-7.1

- Use of Write-Information, Write-Verbose and Write-Debug is strongly encouraged.
- Use of Write-Output, Write-Host and Read-Host is strongly discouraged as this can halt/hang automation and/or cause artifacts when values are returned by a function.
- All functions should have a help file.
- Script files, except the module files, should be prefixed with libUI and end with a one or two word description of the contents (example, libUImain.ps1, libUIcore.ps1, libUIpolicy.ps1, etc.)
- Files MUST include a descriptive purpose of what the contents do.
- All code MUST be well documented.
- Script-level variables should be prefixed with Unifi (example: UnifiEncoding) and put in libUImain.ps1.


Target Compatibility:

- PowerShell 7.1+
- Windows ($IsWindows), Linux ($IsLinux), MacOS ($IsMacOS)
- .NET 5

#>

# default encoding scheme
[string]$script:UnifiEncoding = "utf8bom"


###############
##           ##
##  GETTERS  ##
##           ##
###############

## These functions echo the default settings ##
#region defults
function Get-UnifiDefaultName
{
    return ($script:defaultName)
}

function Get-UnifiDefaultSettingPath
{
    return ($script:defaultSettingPath)
}


function Get-UnifiDefaultSite
{
    return ($script:defaultSite)
}

function Get-UnifiDefaultSession
{
    return ($script:defaultSession)
}

function Get-UnifiDefaultUser
{
    return ($script:defaultUser)
}

function Get-UnifiDefaultHost
{
    return ($script:defaultHost)
}

function Get-UnifiDefaultSkipCertificateCheck
{
    return ($script:SkipCertificateCheck)
}

function Get-UnifiDefaultSkipHeaderValidation
{
    return ($script:SkipHeaderValidation)
}

function Get-UnifiDefaultGroup
{
    return ($script:group)
}

#endregion defults


###############
##           ##
##  SETTERS  ##
##           ##
###############


## These functions set the default settings ##
#region defults

function Set-UnifiDefaultName
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [string]
        $defaultName
    )

    $script:defaultName = $defaultName
}

function Set-UnifiDefaultSettingPath
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [string]
        $defaultSetPath
    )

    $script:defaultSettingPath = $defaultSetPath
}

function Set-UnifiDefaultSite
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [string]
        $defaultSite
    )

    $script:defaultSite = $defaultSite
}

function Set-UnifiDefaultSession
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [string]
        $defaultSession
    )

    $script:defaultSession = $defaultSession
}

function Set-UnifiDefaultUser
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [string]
        $defaultUser
    )

    $script:defaultUser = $defaultUser
}

function Set-UnifiDefaultHost
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [string]
        $defaultHost
    )

    $script:defaultHost = $defaultHost
}

function Set-UnifiDefaultSkipCertificateCheck
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [bool]
        $SkipCertificateCheck
    )

    $script:SkipCertificateCheck = $SkipCertificateCheck
}

function Set-UnifiDefaultSkipHeaderValidation
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [bool]
        $SkipHeaderValidation
    )

    $script:SkipHeaderValidation = $SkipHeaderValidation

    return ($script:SkipHeaderValidation)
}

function Set-UnifiDefaultGroupList
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [UIGroupList[]]
        $GroupList
    )

    $script:defaultGroupList = $GroupList
}

function Set-UnifiDefaultPolicyList
{
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory=$true)]
        [UIPolicyList[]]
        $PolicyList
    )

    $script:defaultPolicyList = $PolicyList
}

#endregion defults


############
##        ##
##  MAIN  ##
##        ##
############

#region

# NAME      : New-UnifiSession
# PURPOSE   : Login and create a web session for future calls.
# INPUTS    : [string] - The site[:port] or ip[:port] to the UniFi controller. This should not contain any prefix, like https://, or a suffix, like /api.
#             [PSCredential] - Optional. UniFi controller credentials in a PSCredential object.
# OUTPUTS   : [WebRequestSession]$uiSession - Contains UniFi session details, including the cookies containing the session tokens. This is needed to authenticate all other calls.

function New-UnifiSession
{
    param ( $uiHost = $null,
            $uiLogon = $null,
            [switch]$Default
    )

    # get credentials
    if (-NOT $uiLogon)
    {
        Write-Information "Please enter your UniFi Controller credentials. Windows users: the username is case sensitive." -InformationAction Continue

        if ($script:defaultUser)
        {
            $uiLogon = Get-Credential -UserName $script:defaultUser
        }
        else 
        {
            $uiLogon = Get-Credential
        }
        
    }

    ## create REST variables ##
    # create the JSON for the body - do not change the spacing!!!
    $uiBody = New-UnifiLoginBody $uiLogon

    $uiMethod = 'POST'

    ## connect to the UniFi Controller ##
    $logonSplat = New-UnifiRESTHeader -uriPath "login" -SessionVariable 'uiSession' -body $uiBody -method $uiMethod
        

    ## make the REST API call ##
    if ($logonSplat)
    {
        $result = Invoke-UnifiRESTMethod $logonSplat -EA Stop
    }
    else 
    {
        Write-Error "Invalid or missing UniFi REST header."
        return $null
    }

    # set this as the global unifi session when -MakeDefault is set
    if ($Default)
    {
        $script:defaultSession = $result
    }

    # return the session to the caller
    return $result
} #end New-UnifiSession


function Select-UnifiSession
{
    param ($uiSession)

    # try the default session if none is provided
    if (-NOT $uiSession)
    {
        if (-NOT $script:defaultSession)
        {
            Write-Error "No Unifi session provided and there is no default session. Please use New-UnifiSession to create a login session."
            return $null
        }
        else 
        {
            $uiSession = $script:defaultSession  
        }
    }

    return $uiSession
}


# NAME      : Close-UnifiSession
# PURPOSE   : Close the currect session.
# INPUTS    : [WebRequestSession]$uiSession - The UI session from New-UnifiSession.
# OUTPUTS   : [bool] - $true if logged out, $false if logout failed.

function Close-UnifiSession
{
    param($uiSession)

    # did we just delete the default session?
    $isDefaultSession = $false
    $originalSession = $uiSession

    # try the default session if none is provided
    $uiSession = Select-UnifiSession $uiSession

    if (-NOT $uiSession)
    {
        return $null
    }
    elseif ($originalSession -eq $script:DefaultSession) 
    {
        $isDefaultSession = $true
    }

    $uiMethod = 'POST'

    ## connect to the UniFi Controller ##
    $logoffSplat = New-UnifiRESTHeader -uriPath "logout" -method $uiMethod -session $uiSession

    ## make the REST API call ##
    if ($logoffSplat)
    {
        $result = Invoke-UnifiRESTMethod $logoffSplat -EA Stop
    }
    else 
    {
        Write-Error "Invalid or missing UniFi REST header."
        return $null
    }

    # clean up the session variables
    $uiSession = $null

    if ($isDefaultSession -or $null -eq $originalSession)
    {
        $script:DefaultSession = $null
    }

    return $true
} #end Close-UnifiSession



#endregion MAIN

