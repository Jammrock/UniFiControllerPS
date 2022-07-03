# libUIrest
#
# Functions that do REST methods for Unifi Controller


# NAME      : 
# PURPOSE   : 
# INPUTS    : []
# OUTPUTS   : []

function New-UnifiRESTHeader
{
    param(
        $uiHost = $null,
        $uriPath = $null,
        $method = "GET",
        $body = $null,
        $session = $null,
        $SessionVariable = $null,
        $SkipCertificateCheck = $false,
        $SkipHeaderValidation = $false
    )

    # find the Unifi host
    if (-NOT $uiHost)
    {
        $uiHost = $script:defaultHost
    }

    # build the base header
    $hdrSplat = @{
        Uri                     = "https://$uiHost/api/$uriPath" 
        ContentType             = "application/json"
        Method                  = $method
    }
    
    # add the WebSession (auth) when we aren't logging in
    if (-NOT $session -and $uriPath -notmatch 'login')
    {
        if (-NOT $script:defaultSession)
        {
            Write-Error "No Unifi session provided and there is no default session. Please use New-UnifiSession to create a login session."
            return $null
        }

        $session = $script:defaultSession  
    }

    if ($session -and $uriPath -notmatch 'login')
    {
        $hdrSplat.Add('WebSession', $session)
    }

    # header body
    if ($body)
    {
        $hdrSplat.Add('Body', $body)
    }

    # SessionVariable is used to return the login information
    if ($SessionVariable)
    {
        $hdrSplat.Add('SessionVariable', $SessionVariable)
    }

    # for self-signed, untrusted certs, this is needed
    if ($SkipCertificateCheck -or $script:SkipCertificateCheck)
    {
        $hdrSplat.Add('SkipCertificateCheck', $true)
    }

    # hopefully this isn't needed, but just in case
    if ($SkipHeaderValidation -or $script:SkipHeaderValidation)
    {
        $hdrSplat.Add('SkipHeaderValidation', $true)
    }

    return $hdrSplat
} #end 


# NAME      : Invoke-UnifiRESTMethod
# PURPOSE   : 
# INPUTS    : []
# OUTPUTS   : []

function Invoke-UnifiRESTMethod
{
    param(
        [hashtable]$headerSplat
    )

    if ($headerSplat -isnot [hashtable])
    {
        Write-Error ("The header must be a hashtable. Please use New-UnifiRESTHeader to create the UniFI REST header.")
        return $null
    }

    # the session cookies will be stored in $uiSession
    try 
    {
        $result = Invoke-RestMethod @headerSplat -EA Stop
    }
    catch 
    {
        Write-Error "Failed to logon to $uiHost`: `n $_"
        return $null
    }

    if ($headerSplat.Uri -match "login")
    {
        return $uiSession
    }
    else 
    {
        return $result.Data
    }
    
} #end Invoke-UnifiRESTMethod



### LOGON ###

# NAME      : New-UnifiLoginBody
# PURPOSE   : Creates the Login Json text
# INPUTS    : [PSCredential] - UniFi username and password
# OUTPUTS   : [string] - A properly structured login string. WARNING!!! This string contains the plaintext password.

function New-UnifiLoginBody
{
    param ([PSCredential]$uiLogon)

    # do not modify the spacing. the body must be an exact match or the call will fail.
    $uiBody = [PSCustomObject]@{
        username = "$($uiLogon.UserName)"
        password = "$($uiLogon.GetNetworkCredential().Password)"
        remember = $true
    } | ConvertTo-Json

    return $uiBody
} #end New-UnifiLoginBody