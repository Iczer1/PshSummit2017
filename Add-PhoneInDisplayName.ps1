<#
.SYNOPSIS
Monitors a group for all members that are user accounts and will append the phone number of the user to the display name of the user name (e.g. “Doe, John” to “Doe,John (215-789-4561)”). 
.DESCRIPTION
TODO
.PARAMETER GroupName 
Group the script will interact with
.PARAMETER Attribute 
Multivalued AD attribute the script will use to store the previous user list
.EXAMPLE
TODO
.NOTES 
#>

[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline = $True, Mandatory = $False, HelpMessage = "Enter the name of the group(s) to watch ")] 
    [string]$GroupName = "SET-PhoneNumberInDisplayName",

    [Parameter(Mandatory = $False)] 
    [string]$Attribute = "msExchExtensionCustomAttribute1"
)


#Bad users list
$UsersWithIssues = @()

#Attemtping to load the AD Module, which is needed to run Set-Aduser and Get-ADUser
#Modules don't error out if they are already loaded so we will try to reload the module
Write-Verbose "Checking if AD module is loaded" 
Try {import-module -Name ActiveDirectory -ErrorAction Stop | Out-Null}
Catch {
    Write-warning "AD module cannot be loaded, exiting sctript and sending email notifcation"
    Exit 1
}#Catch

Try {
    #Get Group DN for User search
    $GroupProps = Get-ADGroup $GroupName -ErrorAction Stop

    #Get previous and current user list
    $PreviousUsers = Get-ADGroup -Identity $GroupName -Properties $Attribute -ErrorAction stop |
        Select-Object -ExpandProperty $Attribute
    <#
    #The [string[]] part is important when setting the variable later
    [String[]]$CurrentUsers = Get-ADGroupMember -Identity $GroupName -ErrorAction stop |
                                Select-Object -ExpandProperty SamAccountName
    #>

    #Getting the group membership this way allows us to get the displayname
    #Otherwise we would have to get the group membership and then do a seperate call for each user in order to get the display name
    [Array]$CurrentUsers = Get-ADUser -LDAPFilter "(memberof=$($GroupProps.DistinguishedName))" -Properties telephoneNumber, DisplayName -ErrorAction Stop |
        Select-Object SamAccountName, Displayname, GivenName, Surname, telephoneNumber
}
Catch {
    Write-Warning "Error accessing AD, full error below:"
    $_
    Exit 0
}

If (-not $PreviousUsers -and -not $CurrentUsers) {
    Write-Verbose "No current or previous users, no work needed"
    Exit 0
}#If (-not $PreviousUsers -and -not $CurrentUsers)
#TODO
#What if someone keeps emptying the attribute

#Find removed users
If ($PreviousUsers) {
    $Difference = Compare-Object -ReferenceObject $PreviousUsers -DifferenceObject $CurrentUsers.samaccountname |
        Where-Object SideIndicator -eq "<=" | 
        Select-Object -ExpandProperty InputObject
    Foreach ($Removeduser in $Difference) {
        Try {
            $UserInfo = Get-ADUser $Removeduser -ErrorAction stop
            Set-ADUser -Identity $Removeduser -DisplayName "$($UserInfo.GivenName) $($UserInfo.SurName)" -ErrorAction stop
        }#try
        Catch {
            Write-warning "Can't edit or find $Removeduser"
            $UsersWithIssues += [pscustomobject]@{
                UserName = $Removeduser
                Activity = 'Changing previous users'
                ExactError = $_
            }
        }#Catch
    }#$Foreach ($Removeduser -in $Difference)
}#If ($PreviousUsers)


#Verify current users are setup correctly
Foreach ($Member in $CurrentUsers) {
    If (-not $Member.telephoneNumber) {
        Write-Warning "$($Member.samaccountname) Doesn't have a telephone Number populated"
        $UsersWithIssues += [pscustomobject]@{
            UserName = $Member.samaccountname
            Activity = 'Verifying current users'
            ExactError = 'Unpopulated telephoneNumber attribute'
        }
        Continue
    }#If (-not $Member.telephoneNumber) 
    
    Try {
        #THOUGHTS : would this be a good oppurtunity to verify the phone number format?
        If ($Member.DisplayName -ne "$($Member.GivenName) $($Member.SurName) ($($Member.telephoneNumber))") {
            Set-ADUser -Identity $Member.samaccountname -DisplayName "$($Member.GivenName) $($Member.SurName) ($($Member.telephoneNumber))" -ErrorAction stop
        }#If ($Member.DisplayName -ne "$($Member.GivenName) $($Member.SurName) ($($Member.telephoneNumber))")
    }#Try
    Catch {
        Write-warning "Can't edit or find $($Member.samaccountname)"
        $UsersWithIssues += [pscustomobject]@{
            UserName = $Member.samaccountname
            Activity = 'Verifying and setting current users'
            ExactError = $_
        }
    }#Catch
}#Foreach ($Member in $CurrentUsers)



#Push current membership to attribute
Try {
    Set-ADGroup -Identity $GroupName -replace @{$Attribute = $CurrentUsers.samaccountname} -ErrorAction stop
}#Try
Catch {
    Write-Warning "Can't write current user membershipt to the following attribute : $Attribute"
    If ($UsersWithIssues) {
        Write-Warning "Also, the following problems occured"
        $UsersWithIssues
    }#If ($UsersWithIssues)
    Exit 1
}#Catch

Write-Verbose "Checking to see if there were Users With issues"
If ($UsersWithIssues) {
    Write-Warning "The following problems occured"
    $UsersWithIssues
    exit 1
}#If ($UsersWithIssues)

