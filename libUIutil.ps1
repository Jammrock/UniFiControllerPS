

#region NETWORK/INTERNET

# NAME      : Set-SecurityProtocols
# PURPOSE   : Makes sure pwsh doesn't try outdated versions of TLS or SSL.
# INPUTS    : none
# OUTPUTS   : none

function Set-SecurityProtocols
{
    # make sure we don't try to use an insecure SSL/TLS protocol when downloading files
    $secureProtocols = @() 
    $insecureProtocols = @( [System.Net.SecurityProtocolType]::SystemDefault, 
                            [System.Net.SecurityProtocolType]::Ssl3, 
                            [System.Net.SecurityProtocolType]::Tls, 
                            [System.Net.SecurityProtocolType]::Tls11) 
    foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType])) 
    { 
        if ($insecureProtocols -notcontains $protocol) 
        { 
            $secureProtocols += $protocol 
        } 
    } 
    [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols
} #end Set-SecurityProtocols


# NAME      : Format-UnifiMac
# PURPOSE   : 
# INPUTS    : []
# OUTPUTS   : []

function Format-UnifiMac
{
    param([string]$mac)
    
    $originalMAC = $mac

    ## format the MAC into a support format, as colon separated values in hex pairs (00:11:22:33:44:55:ff)
    # make it all lower-case
    $mac = $mac.ToLower()
    
    # try and convert the format from the three other main MAC address conventions
    if ($mac -notmatch "^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$")
    {
        # strip out all the hyphens and periods to create a MAC blob
        $mac = $mac.Replace("-","").Replace(".","")

        # make sure the right number of digits are in the MAC blob
        if ($mac -match "^(?:[0-9a-fA-F]{2}){5}[0-9a-fA-F]{2}$")
        {
            # add the colons
            [string]$mac = ($mac -replace '..(?!$)', '$&:')
        }
        # error out if $mac doesn't match the four conventions
        else 
        {
            Write-Error "The MAC (physical) address is invalid or in an unknown format: $originalMAC"
            return $null
        }
    }

    return $mac
} #end 


# NAME      : Find-GitRelease
# PURPOSE   : Use Git APIs to find the newest Git release in a repository (default) or a specific version
# INPUTS    : [string] Repository URL
# OUTPUTS   : [PSCustomObject] Contains an object with the version number(s) and browser download URLs.

function Find-GitRelease
{
    param(
            $RepositoryURL,
            $Version
    )

    # validate URL
    try 
    {
        [uri]$URI = $RepositoryURL
    }
    catch 
    {
        Write-Error "The repository URL is invalid: $_"
        return $null
    }

    ## make the API call
    if (-NOT $Version)
    {
        # does the URL end with /releases/latest add it
        if ($RepositoryURL -match "^.*/releases$")
        {
            $RepositoryURL += "/latest"
        }
        elseif ($RepositoryURL -notmatch "^.*/releases/latest$")
        {
            $RepositoryURL += "/releases/latest"
        }
        [uri]$URI = $RepositoryURL

        # make the API call
        try 
        {
            Set-SecurityProtocols

            $splat = @{
                Method          = "GET"
                Uri             = "https://api.github.com/repos$($URI.AbsolutePath)"
                ContentType     = 'application/vnd.github.v3+json'
                UseBasicParsing = $true
            }

            $result = Invoke-RestMethod @splat -EA Stop
        }
        catch 
        {
            Write-Error "Could not find the latest release for $RepositoryURL`: $_"
            return $null
        }

        # convert the release to a releaseobject
        $version = [System.Version]::New(($result.name.Split(".") -Replace ("\D","") -join '.'))
        $dlURL = $result.assets.browser_download_url

        $release = [PSCustomObject] @{ Version = $Version; Download = $dlURL }
    }
    elseif ($Version)
    {
        # does the URL end with /releases add it
        if ($RepositoryURL -notmatch "^.*//releases$")
        {
            $RepositoryURL += "/releases"
            [uri]$URI = $RepositoryURL
        }

        # make the API call
        try 
        {
            Set-SecurityProtocols

            $splat = @{
                Method          = "GET"
                Uri             = "https://api.github.com/repos$($URI.AbsolutePath)"
                ContentType     = 'application/vnd.github.v3+json'
                UseBasicParsing = $true
            }

            $result = Invoke-RestMethod @splat -EA Stop
        }
        catch 
        {
            Write-Error "Could not find the latest release for $RepositoryURL`: $_"
            return $null
        }
        
        if ($Version -is [System.Version])
        {
            $fndResult = $result | Where-Object { $_.name -match $Version.ToString() }
        }
        else
        {
            $fndResult = $result | Where-Object { $_.name -match $Version }
        }
        
        # convert the release to a releaseobject
        if ($fndResult)
        {
            $version = [System.Version]::New(($fndResult.name.Split(".") -Replace ("\D","") -join '.'))
            $dlURL = $fndResult.assets.browser_download_url

            $release = [PSCustomObject] @{ Version = $Version; Download = $dlURL }
        }
        else 
        {
            Write-Information "Version $Version not found."
            return $null    
        }
    }
    else 
    {
        # something went wrong
        Write-Verbose "Something done messed up! We shouldn't be here."
        return $null    
    }

    return $release

} #end Find-GitRelease

#endregion NETWORK/INTERNET



#region TIME

# NAME      : Get-UnixZeroTime
# PURPOSE   : Returns a [datetime] of Unix zero time, which is 1970.01.01 00:00Z
# INPUTS    : none
# OUTPUTS   : [datetime]

function Get-UnixZeroTime
{
    # %Z gets the UTC offset
    [int]$utcOffset = Get-Date -UFormat %Z

    # Unix epoch time is 01.01.1970 00:00Z, but Get-Date automatically does local time, so subtract the UTC offset hours to get the accurate epoch time
    [datetime]$zTime = (Get-Date 01.01.1970).AddHours($utcOffset)

    return $zTime

} #end Get-UnixZeroTime

# NAME      : ConvertTo-UnixTime
# PURPOSE   : Convert a Windows [datetime] to a Unix timestamp.
# INPUTS    : [datetime]
# OUTPUTS   : [int32]

function ConvertTo-UnixTime
{
    param([datetime]$date)

    return (Get-Date -Date $date -UFormat %s)

} #end ConvertTo-UnixTime

# NAME      : ConvertFrom-UnixTime
# PURPOSE   : Convert a Windows [datetime] to a Unix timestamp.
# INPUTS    : [int32]
# OUTPUTS   : [datetime]

function ConvertFrom-UnixTime
{
    param([int]$timeStamp)

    # this seems to work
    return ((Get-UnixZeroTime).AddSeconds($timeStamp))

} #end ConvertFrom-UnixTime

#endregion TIME
