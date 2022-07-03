# classes and enums for UnifiControllerPS


<#

File format rules:

- No spaces
- All lowercase
- XML file format.
    - All files are based on the output of Export-Clixml. 
    - This preserves data types and allows for easy serialization.
- <id> in all filenames is the string value of a randomly generated GUID.
    - No curly braces ( {} ) in the <id>. 
    - Hex digits and hyphens (-) only.
- No friendly names in filenames to prevent duplication.
    - Should setting files be the exception for user friendliness?


UIClient filenames use the file format:

    uicli_<id>.xml

UIGroup:

    uigrp_<id>.xml

UIPolicy

    uipol_<id>.xml

UISetting

    uiset_<id>.xml



Thoughts:

- All files for a setting (setting, policies, groups, clients) should be in the same dir.
- Settings should default to the module path.
- Workflow:
    - Create a setting, which creates a settings dir.
    - Setting dir is based off the setting name
    - A Setting can be passes to files, which determines where the file is saved.
    - If no setting is passed, then use the default setting.
    - If $Path set, use that. This allows custom file names, when an XML file is passed.

#>


<#

GROUP amd CLIENT related classes and enums

#>

#region GROUP

## group related structures

<# 
    Used for storing a client/device network details.

    Required:
        - Hostname
        - MAC
        - Id (auto-assigned)
#>

class UIClient
{
    [string]$Hostname
    [IPAddress]$IPAddress
    [string]$MAC
    [string]$Site
    [string]$Id

    #region headers
    UIClient()
    {
        $this.Hostname  = $null
        $this.IPAddress = $null
        $this.MAC       = $null
        $this.Site      = $null
        $this.Id        = $null
    }

    UIClient(
        [string]$Hostname,
        [string]$MAC
    )
    {
        $this.Hostname  = $Hostname
        $this.IPAddress = $null
        $this.MAC       = $MAC
        $this.Site      = $null
        $this.Id        = $null
    }

    UIClient(
        [string]$Hostname,
        [IPAddress]$IPAddress,
        [string]$MAC
    )
    {
        $this.Hostname  = $Hostname
        $this.IPAddress = $IPAddress
        $this.MAC       = $MAC
        $this.Site      = $null
        $this.Id        = $null
    }

    UIClient(
        [string]$Hostname,
        [IPAddress]$IPAddress,
        [string]$MAC,
        [string]$Site
    )
    {
        $this.Hostname  = $Hostname
        $this.IPAddress = $IPAddress
        $this.MAC       = $MAC
        $this.Site      = $Site
        $this.Id        = $null
    }

    UIClient([PSCustomObject]$Obj)
    {
        $this.Hostname  = $Obj.Hostname
        $this.IPAddress = $Obj.IPAddress.Address
        $this.MAC       = $Obj.MAC
        $this.Site      = $Obj.Site
        $this.Id        = $Obj.Id
    }
    #endregion headers

    [string]ToString()
    {
        return ("{0},{1},{2},{3}" -f $this.Hostname, $this.MAC, $this.Site, $this.Id)
    }
}


<# 
    Creates a group of member objects used for automation.

    Required:
        - Name
        - Client
        - Id (auto-assigned)

    A client within UIGroup is a [UIClient].Guid to file mapping. Where the file is the saved arraylist, 
    using Export-Clixml, of [UIClient] objects.

    Client Pseudo Template:

    [PSCustomObject]@{
        Guid = [guid]
        File = [string]
    }

    An array of [UIClient] class objects is not used because nested classes can crash PowerShell.

    https://github.com/PowerShell/PowerShell/issues/6652

#>
class UIGroup
{
    [string]$Name
    [string]$Description
    [System.Collections.ArrayList]$Client
    [guid]$ID

    #region headers
    UIGroup()
    {
        $this.Name          = $null
        $this.Description   = $null
        $this.Client        = $null
        $this.ID            = New-Guid
    }

    UIGroup([string]$Name)
    {
        $this.Name          = $Name
        $this.Description   = $null
        $this.Client        = $null
        $this.ID            = New-Guid
    }

    UIGroup(
        [string]$Name, 
        [string]$Desc
    )
    {
        $this.Name          = $Name
        $this.Description   = $Desc
        $this.Client        = $null
        $this.ID            = New-Guid
    }

    UIGroup(
        [string]$Name, 
        [string]$Desc, 
        [System.Collections.ArrayList]$Client
    )
    {
        $this.Name          = $Name
        $this.Description   = $Desc
        $this.Client        = $Client
        $this.ID            = New-Guid
    }

    UIGroup([PSCustomObject]$Obj)
    {
        $this.Name          = $Obj.Name
        $this.Description   = $Obj.Description
        $this.ID            = $Obj.ID
        $this.Client        = $Obj.Client
    }

    #endregion headers

    [System.Management.Automation.ErrorRecord]
    AddClient($Client)
    {
        # add the $client record to the group
        try
        {
            $this.Client += $Client
        }
        catch
        {    
            return (Write-Error "" -EA Stop) 
        }

        return $true
    }

    [System.Management.Automation.ErrorRecord]
    AddClientRange([System.Collections.ArrayList]$Client)
    {
        # add the $Client records to the group
        foreach ($cli in $Client)
        {
            try
            {
                $this.Client += $Client
            }
            catch
            {    
                return (Write-Error "" -EA Stop) 
            }
        }

        return $true
    }

    [void]RemoveClient($Client)
    {
        $this.Client = $this.Client.Remove($Client)
    }

    [void]ClearClient()
    {
        $this.Client = [System.Collections.ArrayList]@()
    }

    [void]ResetClient([UIPolicy[]]$Client)
    {
        $this.ClearClient()
        $this.AddClientRange($Client)
    }

    [System.Collections.ArrayList]GetClientList()
    {
        return $this.Client
    }

    # compare?

    [string]
    ToString()
    {
        return @"
Name        :   $this.Name
Description :   $this.Description
Client      :   $this.Client
"@
    }
}


#endregion GROUP


<#

POLICY related classes and enums. Must be after GROUP due to dependencies.

#>

#region POLICY

# whether the policy should be scheduled at a set day and time, or triggered by an event.
enum UIPolicyType
{
    Schedule    = 0x0
    Trigger     = 0x1
}

# what action the policy should take.
enum UIPolicyAction
{
    Block       = 0x0
    Unblock     = 0x1
}


# defines a schedule-based policy trigger.
class UIPolicyTrigger
{
    [datetime]$At
    [DayOfWeek[]]$DaysOfWeek

    UIPolicyTrigger()
    {
        $this.At         = $null
        $this.DaysOfWeek = $null
    }

    UIPolicyTrigger(
        [datetime]$At,
        [DayOfWeek[]]$DaysOfWeek
    )
    {
        $this.At         = $At
        $this.DaysOfWeek = $DaysOfWeek
    }

    [string]
    ToString()
    {
        return "At: $(Get-Date -Date $this.At -Format HH:mm), DaysOfWeek: $($this.DaysOfWeek)"
    }
}


<# 
    Creates a policy objects used for automation.

    Required:
        - Name
        - Tyep
        - Action
        - Group
        - ID (auto-assigned)

    A group within UIPolicy is a [UIGroup].ID to file mapping. Where the file is the saved arraylist, 
    using Export-Clixml, of [UIGroup] objects.

    Client Pseudo Template:

    [PSCustomObject]@{
        Guid = [guid]
        File = [string]
    }

    An array of [UIGroup] class objects is not used because nested classes crash PowerShell.
    [UIPolicyTrigger] is simple enough that it doesn't seem to crash PowerShell. That and it's not an array of classes.

    https://github.com/PowerShell/PowerShell/issues/6652

#>
class UIPolicy
{
    [string]$Name
    [string]$Description
    [UIPolicyType]$Type
    [UIPolicyAction]$Action
    [UIPolicyTrigger]$Trigger
    [System.Collections.ArrayList]$Group
    [guid]$ID

    #region headers
    UIPolicy()
    {
        $this.Name          = $null
        $this.Description   = $null
        $this.Type          = 0
        $this.Action        = 0
        $this.Trigger       = $null
        $this.Group         = $null
        $this.ID            = (New-Guid)
    }

    UIPolicy(
        [string]$Name,
        [string]$Description,
        [UIPolicyType]$Type,
        [UIPolicyAction]$Action,
        [UIPolicyTrigger]$Trigger,
        [System.Collections.ArrayList]$Group
    )
    {
        $this.Name          = $Name
        $this.Description   = $Description
        $this.Type          = $Type
        $this.Action        = $Action
        $this.Trigger       = $Trigger
        $this.Group         = $Group
        $this.ID            = (New-Guid)
    }

    UIPolicy(
        [string]$Name,
        [UIPolicyType]$Type,
        [UIPolicyAction]$Action,
        [UIPolicyTrigger]$Trigger,
        [System.Collections.ArrayList]$Group
    )
    {
        $this.Name          = $Name
        $this.Description   = $null
        $this.Type          = $Type
        $this.Action        = $Action
        $this.Trigger       = $Trigger
        $this.Group         = $Group
        $this.ID            = (New-Guid)
    }

    # converts a JSON created Policy to a [UIPolicy]
    # this is mainly used for loading policies from file
    UIPolicy([PSCustomObject]$Obj)
    {
        Write-Verbose "[UIPolicy] - Name: $($Obj.Name)"
        $this.Name          = $Obj.Name
        
        Write-Verbose "[UIPolicy] - Desc: $($Obj.Description) "
        $this.Description   = $Obj.Description

        Write-Verbose "[UIPolicy] - Type: $($Obj.Type)"
        $this.Type          = [UIPolicyType]($Obj.Type)

        Write-Verbose "[UIPolicy] - Action: $($Obj.Action)"
        $this.Action        = [UIPolicyAction]($Obj.Action)
        
        Write-Verbose "[UIPolicy] - Trigger: $($Obj.Trigger)"
        $this.Trigger       = [UIPolicyTrigger]::New($Obj.Trigger.At, $Obj.Trigger.DaysOfWeek)

        # make sure there's something in Group or create a null object
        Write-Verbose "[UIPolicy] - Trigger: $($Obj.Group)"
        $this.Group         = $Obj.Group

        # don't change the ID, use the one passed
        $this.ID            = $Obj.ID
    }

    #endregion headers

    # add a single [Group]... kind of
    [System.Management.Automation.ErrorRecord]
    AddGroup($Group)
    {
        try
        {
            $this.Group += $Group
        }
        catch
        {    
            return (Write-Error "" -EA Stop) 
        }

        return $true
    }

    [System.Management.Automation.ErrorRecord]
    AddGroupRange($Group)
    {
        # add the $Client records to the group
        foreach ($grp in $Group)
        {
            try
            {
                $this.Group += $grp
            }
            catch
            {    
                return (Write-Error "" -EA Stop) 
            }
        }

        return $true
    }

    # remove a group from the [Groupp[]] array
    [void]RemoveGroup($Group)
    {
        $this.Group = $this.Group.Remove($Group)
    }

    # clear the $Group by setting it to an empty arraylist
    [void]ClearGroup()
    {
        $this.Group = [System.Collections.ArrayList]@()
    }

    # clear the Group and replace it with the provided [Group[]]
    [void]ResetGroup([System.Collections.ArrayList]$Group)
    {
        $this.ClearGroup()
        $this.Group = $Group
    }

    # by returning an ErrorRecord the Save method can create a terminating error in a caller using a try-catch
    [System.Management.Automation.ErrorRecord]
    Save($Filename)
    {
        # convert the filename to a string if we get a filesystem object from something like Get-Item
        if ($Filename -is [System.IO.FileSystemInfo])
        {
            $Filename = $Filename.Fullname
        }

        # make sure the file is valid
        if (-NOT (Test-Path "$Filename" -IsValid))
        {
            # return a terminating error
            return (Write-Error "[UIPolicy].Save - The filename is invalid: $Filename" -EA Stop)
        }

        # no check if the file exists. This function explicitly overwrites the existing content

        try 
        {
            $this | ConvertTo-Json -Depth 20 | Out-File "$Filename" -Force -Encoding $script:UnifiEncoding -EA Stop
        }
        catch 
        {
            # return a terminating error
            return (Write-Error "[UIPolicy].Save - Could not save the settings file: $_" -EA Stop)
        }

        # return a nonterminating null
        return $null
    }

    [string]
    ToString()
    {
        return @"
Name        :   $this.Name
Description :   $this.Description
Type        :   $this.Type
Action      :   $this.Action
Trigger     :   $($this.Trigger.ToString())
Group       :   $($this.Group)
ID          :   $($this.ID.Guid)
"@
    }
}



#endregion POLICY


<#

SETTINGS related classes and enums. Must be last due to dependencies in POLICY and GROUP.

#>

#region SETTINGS


<# 
    Creates a settings objects used for automation.

    Required:
        - Name
        - Path
        - UnifiHost
        - SiteName
        - ID (auto-assigned)

    A policy within UISetting is a [UIPolicy].ID to file mapping. Where the file is the saved arraylist, 
    using Export-Clixml, of [UIPolicy] objects.

    Client Pseudo Template:

    [PSCustomObject]@{
        Guid = [guid]
        File = [string]
    }

    An array of [UIPolicy] class objects is not used because nested classes crash PowerShell.

    https://github.com/PowerShell/PowerShell/issues/6652


    Data hierarchy:

    A UISetting points to one or more UIPolicy
    UIPolicy ==> UIGroup[]
    UIGroup ==> UIClient[]

    This gives a UISetting the ability to load the necessary policies, groups, and clients without hitting any nested class bugs.

#>
class UISetting
{
    [string]$Name
    [string]$Description
    [string]$Path           # Path must be a string in case the path does not exist at the time the class is created. Get-Item/[System.IO.FileSystem] won't work if the path does not already exist.
    [string]$UnifiHost
    [string]$SiteName
    [string]$UserName
    [bool]$SkipCertificateCheck
    [bool]$SkipHeaderValidation
    [System.Collections.ArrayList]$Policy
    [guid]$ID

    #region headers
    UISetting()
    {
        $this.Name                  = $null
        $this.Description           = $null
        $this.Path                  = $null
        $this.UnifiHost             = $null
        $this.SiteName              = $null
        $this.UserName              = $null
        $this.SkipCertificateCheck  = $false
        $this.SkipHeaderValidation  = $false
        $this.Policy                = [System.Collections.ArrayList]@()
        $this.ID                    = New-Guid

    }

    UISetting(
        [string]$Name,
        [string]$Path,
        [string]$UnifiHost,
        [string]$SiteName,
        [string]$UserName
    )
    {
        $this.Name                  = $Name
        $this.Description           = $null
        $this.Path                  = $Path
        $this.UnifiHost             = $UnifiHost
        $this.SiteName              = $SiteName
        $this.UserName              = $UserName
        $this.SkipCertificateCheck  = $false
        $this.SkipHeaderValidation  = $false
        $this.Policy                = [System.Collections.ArrayList]@()
        $this.ID                    = New-Guid
    }

    UISetting(
        [string]$Name,
        [string]$Path,
        [string]$UnifiHost,
        [string]$SiteName,
        [string]$UserName,
        [bool]$SkipCertificateCheck
    )
    {
        $this.Name                  = $Name
        $this.Description           = $null
        $this.Path                  = $Path
        $this.UnifiHost             = $UnifiHost
        $this.SiteName              = $SiteName
        $this.UserName              = $UserName
        $this.SkipCertificateCheck  = $SkipCertificateCheck
        $this.SkipHeaderValidation  = $false
        $this.Policy                = [System.Collections.ArrayList]@()
        $this.ID                    = New-Guid
    }

    UISetting(
        [string]$Name,
        [string]$Path,
        [string]$UnifiHost,
        [string]$SiteName,
        [string]$UserName,
        [bool]$SkipCertificateCheck,
        [bool]$SkipHeaderValidation
    )
    {
        $this.Name                  = $Name
        $this.Description           = $null
        $this.Path                  = $Path
        $this.UnifiHost             = $UnifiHost
        $this.SiteName              = $SiteName
        $this.UserName              = $UserName
        $this.SkipCertificateCheck  = $SkipCertificateCheck
        $this.SkipHeaderValidation  = $SkipHeaderValidation
        $this.Policy                = [System.Collections.ArrayList]@()
        $this.ID                    = New-Guid
    }

    UISetting(
        [string]$Name,
        [string]$Path,
        [string]$UnifiHost,
        [string]$SiteName,
        [string]$UserName,
        [bool]$SkipCertificateCheck,
        [bool]$SkipHeaderValidation,
        [System.Collections.ArrayList]$Policy
    )
    {
        $this.Name                  = $Name
        $this.Description           = $null
        $this.Path                  = $Path
        $this.UnifiHost             = $UnifiHost
        $this.SiteName              = $SiteName
        $this.UserName              = $UserName
        $this.SkipCertificateCheck  = $SkipCertificateCheck
        $this.SkipHeaderValidation  = $SkipHeaderValidation
        $this.Policy                = $Policy
        $this.ID                    = New-Guid
    }

    UISetting(
        [string]$Name,
        [string]$Description,
        [string]$Path,
        [string]$UnifiHost,
        [string]$SiteName,
        [string]$UserName,
        [bool]$SkipCertificateCheck,
        [bool]$SkipHeaderValidation,
        [System.Collections.ArrayList]$Policy
    )
    {
        $this.Name                  = $Name
        $this.Description           = $Description
        $this.Path                  = $Path
        $this.UnifiHost             = $UnifiHost
        $this.SiteName              = $SiteName
        $this.UserName              = $UserName
        $this.SkipCertificateCheck  = $SkipCertificateCheck
        $this.SkipHeaderValidation  = $SkipHeaderValidation
        $this.Policy                = $Policy
        $this.ID                    = New-Guid
    }

    
    # no arrays allowed!
    UISetting( [PSCustomObject]$set )
    {
        # add the basic stuff
        Write-Verbose "[UISetting] - Adding Name $($set.Name)."
        $this.Name             = $set.Name

        Write-Verbose "[UISetting] - Adding Description $($set.Description)."
        $this.Description             = $set.Description

        Write-Verbose "[UISetting] - Adding Path $($set.Path)."
        if ((Test-Path "$($set.Path)" -IsValid))
        {
            $this.Path                  = $set.Path
        }
        else 
        {
            Write-Error "[UISetting] - Path is invalid: $($set.Path)" -EA Stop
        }

        Write-Verbose "[UISetting] - Adding UnifiHost $($set.UnifiHost)."
        $this.UnifiHost             = $set.UnifiHost

        Write-Verbose "[UISetting] - Adding SiteName $($set.SiteName)."
        $this.SiteName              = $set.SiteName

        Write-Verbose "[UISetting] - Adding UserName $($set.UserName)."
        $this.UserName              = $set.UserName

        Write-Verbose "[UISetting] - Adding SkipCertificateCheck $($set.SkipCertificateCheck)."
        $this.SkipCertificateCheck  = $set.SkipCertificateCheck

        Write-Verbose "[UISetting] - Adding SkipHeaderValidation $($set.SkipHeaderValidation)."
        $this.SkipHeaderValidation  = $set.SkipHeaderValidation
       
        # add policies
        Write-Verbose "[UISetting] - Adding policies: $($set.Policy | Format-Table -AutoSize | Out-String)."
        $this.Policy                = $set.Policy

        # generate a GUID if one is not passed
        if ($set.Id)
        {
            Write-Verbose "[UISetting] - Adding Id $($set.Id)."
            $this.ID                    = $set.Id
        }
        else 
        {
            Write-Verbose "[UISetting] - Generating new Setting Id."
            $this.ID                    = New-Guid
        }
    }

    #endregion headers

    [System.Management.Automation.ErrorRecord]
    AddPolicy($Policy)
    {
        try
        {
            $this.Policy += $Policy
        }
        catch
        {    
            return (Write-Error "" -EA Stop) 
        }

        return $true
    }

    [System.Management.Automation.ErrorRecord]
    AddPolicyRange([System.Collections.ArrayList]$Policy)
    {
        # add the $Client records to the group
        foreach ($pol in $Policy)
        {
            try
            {
                $this.Policy += $pol
            }
            catch
            {    
                return (Write-Error "" -EA Stop) 
            }
        }

        return $true
    }

    [void]RemovePolicy($Policy)
    {
        $this.Policy = $this.Policy.Remove($Policy)
    }

    [void]ClearPolicy()
    {
        $this.Policy = [System.Collections.ArrayList]@()
    }

    [void]ResetPolicy([UIPolicy[]]$Policy)
    {
        $this.ClearPolicy()
        $this.AddPolicyRange($Policy)
    }


    [string]ToString()
    {
        return @"
UnifiHost               : $($this.UnifiHost)
SiteName                : $($this.SiteName)
UserName                : $($this.UserName)
SkipCertificateCheck    : $($this.SkipCertificateCheck)
SkipHeaderValidation    : $($this.SkipHeaderValidation)
Policy                  : $($this.Policy)
"@
    }

        # by returning an ErrorRecord the Save method can create a terminating error in a caller using a try-catch
        [System.Management.Automation.ErrorRecord]
        Save($Filename)
        {
            # convert the filename to a string if we get a filesystem object from something like Get-Item
            if ($Filename -is [System.IO.FileSystemInfo])
            {
                $Filename = $Filename.Fullname
            }
    
            # make sure the file is valid
            if (-NOT (Test-Path "$Filename" -IsValid))
            {
                # return a terminating error
                return (Write-Error "[UnifiSetting].Save - The filename is invalid: $Filename" -EA Stop)
            }
    
            # no check if the file exists. This function explicitly overwrites the existing content
    
            try 
            {
                $this | ConvertTo-Json -Depth 20 | Out-File "$Filename" -Force -Encoding unicode -EA Stop
            }
            catch 
            {
                # return a terminating error
                return (Write-Error "[UnifiSetting].Save - Could not save the settings file: $_" -EA Stop)
            }
    
            # return a nonterminating null
            return $null
        }
    
}

#endregion SETTINGS
