<#

Manages cmdlets for Unifi clients.

A client is network device - laptop, desktop, table, phone, etc. - connected to Unifi equipment.

A device, in Unifi terminology, is Unifi hardware - router, switch, AP, etc. These functions to do not manage devices.

#>


###############
##           ##
##  GETTERS  ##
##           ##
###############

#region

# NAME      : Get-UnifiClient
# PURPOSE   : Gets an array of clients. No filtering here. Just the raw list that comes back from the controller.
# INPUTS    : [WebRequestSession]$uiSession - The UI session from New-UnifiSession.
# OUTPUTS   : [PSCustomObject[]] - Array of active client objects.

function Get-UnifiClient
{
    param(
        $uiSession = $null,
        $site = $null
    )

    # make sure we have a site
    $site = Select-UnifiSite $site
    

    #  https://unifi.kehr.home:8443/api/s/vbt53z6c/cmd/manager
    ## connect to the UniFi Controller ##
    $clientSplat = New-UnifiRESTHeader -uriPath "s/$site/stat/sta" -session $uiSession

    ## make the REST API call ##
    # the session cookies will be stored in $uiSession
    try 
    {
        $results = Invoke-UnifiRestMethod $clientSplat -EA Stop
    }
    catch 
    {
        Write-Error "Failed to get self at $uiHost`: `n $_"
        return $null
    }

    return ($results)

} #end Get-UnifiClient








#endregion GETTERS



###############
##           ##
##  SETTERS  ##
##           ##
###############

#region














#endregion SETTERS



############
##        ##
##  MAIN  ##
##        ##
############

#region


# Saves an array of clients to an Export-Clixml generated file.
function Save-UnifiClient
{
    [CmdletBinding()]
    param (
        # Client(s) to be saved. Must be an ArrayList, or parsable to an ArrayList, of [UIClient] objects.
        [Parameter( Mandatory=$true,
                    ValueFromPipeline=$true)]
        [System.Collections.ArrayList]
        $Client,

        # Path to the file. Must point to a directory. The filename is auto-generated and returned.
        [Parameter( Mandatory=$true,
                    ValueFromPipeline=$false)]
        $Path,

        [Parameter( Mandatory=$false,
                    ValueFromPipeline=$false)]
        [switch]
        $Append,

        [Parameter( Mandatory=$false,
                    ValueFromPipeline=$false)]
        [switch]
        $Force
    )

    begin
    {
        ## PATH VALIDATION ##
        # is the $path valid.
        if (-NOT (Test-Path "$Path" -IsValid))
        {
            return (Write-Error "The path is not valid ($($Path)): $_" -EA Stop)
        }

        # does the path exist?
        $isPathFnd = Get-Item "$Path" -EA SilentlyContinue

        if (-NOT $isPathFnd)
        {
            # at this point we can assume the path is a string, because Get-Item does not work with paths that do not exist

            # make sure the path does not end in a file extension
            if ((Split-Path "$Path" -Extension))
            {
                return (Write-Error "Save-UnifiClient Path must be a directory/container. The filename is auto-generated." -EA Stop)
            }

            # at this point we can assume $path is a string pointing to a directory that does not exist.
            # time to make the donuts!
            try 
            {
                $null = New-Item "$Path" -ItemType Directory -Force -EA Stop
            }
            catch 
            {
                return (Write-Error "Failed to create the directory ($Path): $_" -EA Stop)
            }
        }

        # convert a path string to System.IO.FileSystemInfo object
        if ($Path -is [string])
        {
            try 
            {
                $path = Get-Item "$Path" -EA Stop    
            }
            catch 
            {
                
            }        
        }

        ## CLIENT VALIDATION ##
        # make sure the objects in $Client are all [UIClient] objects
        foreach ($cli in $Client)
        {
            if ($cli -ne [UIClient])
            {
                return (Write-Error "Invalid client object found. All objects in the Client array must be [UIClient] objects. $($cli.ToString())" -EA Stop)
            }
        }

        # don't need to validate an array, since that will be caught by the param block long before we get here.
        # validation done. Nothing else to do here
    }

    process{} # don't need to process anything since we want to write everything at once for performance reasons

    end
    {
        # generate a path with filename. See libUIclasses for da rulez.
        $fileName = "$($Path.FullName)\uicli_$((New-Guid).Guid).xml"
    }

}












#endregion SETTERS