<#

Contains cmdlets for Unifi site related work.

#>


###############
##           ##
##  GETTERS  ##
##           ##
###############

#region


# NAME      : Get-UnifiSite
# PURPOSE   : Gets the details of the session user account.
# INPUTS    : [WebRequestSession]$uiSession - The UI session from New-UnifiSession.
# OUTPUTS   : [PSCustomObject] - An object table of user details.

function Get-UnifiSite
{
    param($uiSession)

    ## connect to the UniFi Controller ##
    $siteSplat = New-UnifiRESTHeader -uriPath 'self/sites' -session $uiSession

    ## make the REST API call ##
    # the session cookies will be stored in $uiSession
    try 
    {
        $results = Invoke-UnifiRestMethod $siteSplat -EA Stop
    }
    catch 
    {
        Write-Error "Failed to get sites from $uiHost`: `n $_"
        return $null
    }

    return ($results)
} #end Get-UnifiSite



# NAME      : Get-UnifiSiteStats
# PURPOSE   : Gets the details of the session user account.
# INPUTS    : [WebRequestSession]$uiSession - The UI session from New-UnifiSession.
# OUTPUTS   : [PSCustomObject] - An object table of user details.

function Get-UnifiSiteStats
{
    param($uiSession)

    ## connect to the UniFi Controller ##
    $statSplat = New-UnifiRESTHeader -uriPath 'stat/sites' -session $uiSession

    ## make the REST API call ##
    # the session cookies will be stored in $uiSession
    try 
    {
        $results = Invoke-UnifiRestMethod $statSplat -EA Stop
    }
    catch 
    {
        Write-Error "Failed to get sites from $uiHost`: `n $_"
        return $null
    }

    return ($results)
} #end Get-UnifiSiteStats


#endregion GETTERS




###############
##           ##
##  SETTERS  ##
##           ##
###############

#region

<#
Set-UnifiSite
{
    # pending
}
#>

#endregion SETTERS




############
##        ##
##  MAIN  ##
##        ##
############

#region


function Select-UnifiSite
{
    param($site = $null)

    <#
        Site selection priority:

        1. Passed site.
        2. Default site.
        3. last_site_name from the current logged on user. 
    
    #>
    if (-NOT $site)
    {
        if ($script:defaultSite)
        {
            $site = $script:defaultSite
        }
        else 
        {
            # get the site of the logged on user
            $site = (Get-UnifiUser).last_site_name   
        }
    }

    # make sure the site is valid before returning
    $siteList = Get-UnifiSite

    if ($site -in $siteList.name -or $site -in $siteList._id)
    {
        return $site
    }
    else 
    {
        return $null    
    }    
}




#endregion MAIN