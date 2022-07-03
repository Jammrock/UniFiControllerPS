# libUIsettings

<#
    Manages UnifiControllerPS settings.
#>



###############
##           ##
##  GETTERS  ##
##           ##
###############
#region GETTERS

# NAME      : Get-UnifiSetting
# PURPOSE   : Collects persistent settings, creates default script variables, returns settings object
# INPUTS    : [string]$user - username containing the settings
#             [string]$path - path to settings file
# OUTPUTS   : [PSCustomObject] 

function Get-UnifiSetting
{
    param(  
        [string]$User = $null,
        [string]$Path = $null,
        [switch]$Default
    )

    Write-Verbose "Get-UnifiSetting: Start."
    # generate a path to the user settings
    if ($user)
    {
        if ($IsWindows)
        {
            $path = "$(Split-Path $env:USERPROFILE -Parent)\$user\AppData\Local\UniFiControllerPS\settings.xml"
        }
        else 
        {
            Write-Warning "Not yet supported."
            return $null
        }
    }
    # use default locations
    elseif (-NOT $path) 
    {
        if ($IsWindows)
        {
            $path = "$env:LOCALAPPDATA\UniFiControllerPS\settings.xml"
        }
        else 
        {
            Write-Warning "Not yet supported."
            return $null
        }
    }

    # make sure the settings file is found
    Write-Verbose "Get-UnifiSetting: Validate file existence."
    try 
    {
        $pathObj = Get-Item "$path" -EA Stop
        Write-Verbose "Get-UnifiSetting: File found."
    }
    catch 
    {
        return (Write-Error "Settings file not found at $path`: $_" -EA Stop)
    }

    # using Clixml allows for easier serialization/deserialzation of the class structure over using JSON, which doesn't support data types.
    try 
    {
        $fileValid = Test-UnifiSettingFile -File "$path" -EA Stop
        Write-Verbose "Get-UnifiSetting: File passed validation."
    }
    catch 
    {
        return (Write-Error "Get-UnifiSetting: File failed validation: $_")
    }

    # import the settings now that they have been tested
    Write-Verbose "Get-UnifiSetting: Importing settings."
    $settings = [UISetting]::New( ( Import-Clixml "$modPath\setting.xml" ) )

    if ($Default.IsPresent)
    {
        $setSplat = @{
            Name                    = $settings.Name
            Path                    = $settings.Path
            UnifiHost               = $settings.UnifiHost
            UnifiSite               = $settings.SiteName
            UnifiUser               = $settings.UserName
            SkipCertificateCheck    = $settings.SkipCertificateCheck
            SkipHeaderValidation    = $settings.SkipHeaderValidation
            UnifiGroup              = $settings.Group
            UnifiPolicy             = $settings.Policy
        }

        Write-Verbose "Get-UnifiSetting: Making settings the session defaults."
        Set-UnifiDefaultSetting @setSplat

        $script:UnifiSettings = $settings

        # quietly exit when saving to defaults
        Write-Verbose "Get-UnifiSetting: End."
        return $null
    }

    Write-Verbose "Get-UnifiSetting: Returning settings."
    Write-Verbose "Get-UnifiSetting: End."
    return $settings

} #end Get-UnifiSetting



function Get-UnifiDefaultSetting
{
    return ($script:UnifiSettings)
} #end Get-UnifiDefaultSetting





#endregion GETTERS




###############
##           ##
##  SETTERS  ##
##           ##
###############
#region SETTERS


# NAME      : Set-UnifiDefaultHost
# PURPOSE   : Sets the default UniFi controller host in host:port or IP:port format
# INPUTS    : [string]$url - Unifi controller host details.
# OUTPUTS   : [PSCustomObject] updated settings object

function Set-UnifiDefaultSetting
{
    param(
        [string]$Name,
        [string]$Path,
        [string]$UnifiHost = $null,
        [string]$UnifiSite = $null,
        [string]$UnifiUser = $null,
        $SkipCertificateCheck = $null,
        $SkipHeaderValidation = $null,
        $UnifiGroup = $null,
        $UnifiPolicy = $null,
        [switch]$SessionOnly
    )

    if ($Name)
    {
        Set-UnifiDefaultName $Name
    }

    if ($Path)
    {
        Set-UnifiDefaultSettingPath $Path
    }

    if ($UnifiHost)
    {
        Set-UnifiDefaultHost $UnifiHost
    }

    if ($UnifiSite)
    {
        Set-UnifiDefaultSite $UnifiSite
    }

    if ($UnifiUser)
    {
        Set-UnifiDefaultUser $UnifiUser
    }

    if ($SkipCertificateCheck)
    {
        Set-UnifiDefaultSkipCertificateCheck $SkipCertificateCheck
    }
    
    if ($SkipHeaderValidation)
    {
        Set-UnifiDefaultSkipHeaderValidation $SkipHeaderValidation
    }

    if ($UnifiGroup)
    {
        $script:defaultGroup = $UnifiGroup
    }

    if ($UnifiPolicy)
    {
        $script:defaultPolicy = $UnifiPolicy
    }

} #end Set-UnifiDefaultHost



#endregion SETTERS


############
##        ##
##  MAIN  ##
##        ##
############
#region MISC


# NAME      : Test-UnifiSettingFile
# PURPOSE   : 
# INPUTS    : []
# OUTPUTS   : []

function Test-UnifiSettingFile
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $File
    )

    Write-Verbose "Test-UnifiSetting: Start."
    Write-Verbose "Test-UnifiSetting: File exists?"
    $isFile = Get-Item "$file" -EA SilentlyContinue

    if (-NOT $isFile)
    {
        return (Write-Error "Test-UnifiSetting: $($Error[0].toString())" -EA Stop)
    }

    # does the file import and deserialize
    Write-Verbose "Test-UnifiSetting: Does the file deserialize?"
    try 
    {
        $setting = [UISetting]::New(( Import-Clixml "$file" ))    
    }
    catch 
    {
        return (Write-Error "Test-UnifiSetting: Failed to deserialize $file`: $_" -EA Stop)
    }
    
    # does the file have the required components?
    Write-Verbose "Test-UnifiSetting: Validating required setting properties."
    Write-Verbose "Test-UnifiSetting: UnifiHost found?"
    if ($null -ne $setting.UnifiHost -and $setting.UnifiHost -ne "")
    {
        Write-Verbose "Test-UnifiSetting: UnifiHost found!"
        
        # split host from port if a colon (:) is found. Assumes the host is in <URL>:<port> format.
        if ($setting.UnifiHost -match ':')
        {
            [string]$UIhost = $setting.UnifiHost.Split(':')[0]
            [int]$UIport = $setting.UnifiHost.Split(':')[1]
        }
        else
        {
            # assume the default HTTPS port is 443 if no port is given
            [string]$UIhost = $setting.UnifiHost
            [int]$UIport = 443

        }
        
        # make sure the controller is responding
        # this is a non-terminating error, merely a warning
        if ( (Test-NetConnection -ComputerName $UIhost -Port $UIport -InformationLevel Quiet) )
        {
            Write-Verbose "Test-UnifiSetting: UnifiHost responding."
        }
        else
        {
            Write-Warning "Test-UnifiSetting: UnifiHost not responding ($($setting.UnifiHost))."
        }
        
    }
    else 
    {
        Write-Error "Test-UnifiSetting: UnifiHost not found."
        return $false    
    }

    Write-Verbose "Test-UnifiSetting: SiteName populated?"
    if ($null -ne $setting.SiteName -and $setting.SiteName -ne "")
    {
        Write-Verbose "Test-UnifiSetting: Yes."
    }
    else 
    {
        Write-Error "Test-UnifiSetting: SiteName not populated!"
        return $false    
    }

    # none of the other settings are strictly required
    # username is not required for security reasons

    Write-Verbose "Test-UnifiSetting: End."
    return $true

} #end Validate-UnifiSetting


function New-UnifiSetting
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$false)]
        [string]
        $Description,

        [Parameter(Mandatory=$false)]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $UnifiHost,

        [Parameter(Mandatory=$true)]
        [string]
        $SiteName,

        [string]$UserName,
        [bool]$SkipCertificateCheck,
        [bool]$SkipHeaderValidation,
        [System.Collections.ArrayList]$Policy,

        # Makes the new setting the default settings
        [switch]$Default
    )

    $newSet = [UISetting]::New()

    # populate the basic parameters
    $newSet.Name        = $Name
    $newSet.Description = $Description

    # $Path needs some validation
    # Start with whether there is a path
    if ($null -eq $Path -or $Path -eq "")
    {

        # decision time!
        Write-Verbose "New-UnifiSetting - Finding a settings path."
        # if there is a $script:modPath we put it there based on the format: set-<Name>
        if ($script:modPath)
        {
            Write-Verbose "New-UnifiSetting - Picking module path: $($script:modPath)."
            #  the full path to the settings dir
            $setPath = "$script:modPath\set-$($Name.Replace(" ",'_'))"

            # assume the modPath is valid
        }
        # if there is no modPath then use $PWD
        else
        {
            #  the full path to the settings dir
            Write-Verbose "New-UnifiSetting - Picking present working directory: $($PWD.Path)."
            $setPath = "$($PWD.Path)\set-$($Name.Replace(" ",'_'))"

            # assume the pwd is valid
        }

        Write-Verbose "New-UnifiSetting - The settings path is now: $setPath"

        # does setPath already exist?
        $ifSetPath = Get-Item "$setPath" -EA SilentlyContinue

        if (-NOT $ifSetPath)
        {
            Write-Verbose "New-UnifiSetting - Setting path not found. Creating it."
            # create the setting in the module path
            try 
            {
                Write-Verbose "New-UnifiSetting - Creating settings path at: $setPath"
                $null = New-Item "$setPath" -ItemType Directory -Force -EA Stop
            }
            catch 
            {
                return (Write-Error "Could not create a settings path ($setPath): $_" -EA Stop)
            }

            $newSet.Path = $setPath
        }   
    }
    # we have a path value, use that
    else
    {
        # so make sure it is a valid path
        if ((Test-Path "$Path" -IsValid))
        {
            # make sure this is a directory (container) and not a file
            $isPathDir = Get-Item "$Path" -EA SilentlyContinue
            if ($isPathDir.PSIsContainer)
            {
                $newSet.Path = $Path
            }
            else 
            {
                return (Write-Error "The settings path is not a directory: $setPath)" -EA Stop)
            }
        }
        # error out
        else 
        {
            return (Write-Error "The settings path is invalid: $setPath)" -EA Stop)
        }
    }

    # do more settings
    $newSet.UnifiHost   = $UnifiHost
    $newSet.SiteName    = $SiteName
    $newSet.UserName    = $UserName
    

    # change the skips if they are $true
    if ($SkipCertificateCheck)
    {
        $newSet.SkipCertificateCheck = $SkipCertificateCheck
    }

    if ($SkipHeaderValidation)
    {
        $newSet.SkipHeaderValidation = $SkipHeaderValidation
    }

    # add $policy of the array count is greater than 0
    if ($Policy.Count -gt 0)
    {
        $newSet.Policy.AddPolicyRange($Policy)
    }

    if ($Default.IsPresent)
    {
        $setSplat = @{
            Name        = $newSet.Name
            Path        = $newSet.Path
            UnifiHost = $newSet.UnifiHost
            UnifiSite = $newSet.SiteName
            UnifiUser = $newSet.UserName
            SkipCertificateCheck = $newSet.SkipCertificateCheck
            SkipHeaderValidation = $newSet.SkipHeaderValidation
            UnifiPolicy = $newSet.Policy
        }

        Write-Verbose "New-UnifiSetting: Making settings the session defaults."
        Set-UnifiDefaultSetting @setSplat

        $script:UnifiSettings = $newSet

        # quietly exit when saving to defaults
        Write-Verbose "New-UnifiSetting: End."
        return $null
    }

    return $newSet
}



#endregion MISC