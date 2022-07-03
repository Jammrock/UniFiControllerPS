# functions for groups



function Save-UnifiClientGroup
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$false)]
        $Path,
        
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)]
        [System.Collections.ArrayList]
        $Group
    )

    begin
    {
        Write-Verbose "Save-UnifiClientGroup - Start."
        #Write-Verbose "Save-UnifiClientGroup - "
        # convert the filename to a string if we get a filesystem object from something like Get-Item
        if ($Path -is [System.IO.FileSystemInfo])
        {
            Write-Verbose "Save-UnifiClientGroup - Converting FileSystemInfo to string path."
            $Path = $Path.Fullname
        }

        # make sure the file is valid
        Write-Verbose "Save-UnifiClientGroup - Is the file location valid?"
        if (-NOT (Test-Path "$Path" -IsValid))
        {
            # return a terminating error
            return (Write-Error "Save-UnifiClientGroup - The filename is invalid: $Path" -EA Stop)
        }
        else
        {
            Write-Verbose "Save-UnifiClientGroup - Yes."
        }
    }
    process{}
    end
    {
        # no check if the file exists. This function explicitly overwrites the existing content
        Write-Verbose "Save-UnifiClientGroup - Saving UIGroup to file: $Path"
        try 
        {
            $Group | Export-Clixml "$Path" -Force -Encoding $script:UnifiEncoding -EA Stop
        }
        catch 
        {
            # return a terminating error
            return (Write-Error "Save-UnifiClientGroup - Could not save the group to file: $_" -EA Stop)
        }

        # return a nonterminating null
        Write-Verbose "Save-UnifiClientGroup - End."
        return $null
    }

}