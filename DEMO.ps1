
#Show multivalued attribute for test group that holds the list of previous users
(Get-ADGroup SET-PhoneNumberInDisplayName -Properties msExchExtensionCustomAttribute1)
(Get-ADGroup SET-PhoneNumberInDisplayName -Properties msExchExtensionCustomAttribute1).msExchExtensionCustomAttribute1

#Testing pushing various Array formats to the multivalued attribute
$array1 = (Get-ADGroupMember SET-PhoneNumberInDisplayName).samaccountname
$array2 = Get-ADGroupMember SET-PhoneNumberInDisplayName | Select-Object -ExpandProperty samaccountname
[array]$array3 = Get-ADGroupMember SET-PhoneNumberInDisplayName | Select-Object -ExpandProperty samaccountname
[string[]]$array4 = Get-ADGroupMember SET-PhoneNumberInDisplayName | Select-Object -ExpandProperty samaccountname

#Note that certain varations of the array error out when you try to push it to the Array
Write-Output "Foreach method array"
Set-ADGroup -Identity SET-PhoneNumberInDisplayName -Add @{msExchExtensionCustomAttribute3=$array1}
Write-Output "Foreach array"
Set-ADGroup -Identity SET-PhoneNumberInDisplayName -Add @{msExchExtensionCustomAttribute3=$array2}
Write-Output "Strongly typed array"
Set-ADGroup -Identity SET-PhoneNumberInDisplayName -Add @{msExchExtensionCustomAttribute3=$array3}
Write-Output "Strongly typed string array"
Set-ADGroup -Identity SET-PhoneNumberInDisplayName -Add @{msExchExtensionCustomAttribute3=$array4}


#So What's the difference? Not sure!
($array1.GetType() | GM | Where MemberType -eq Property).Name | ForEach-Object {Compare-Object $array2.GetType().$_ $array1.GetType().$_} 
$array3.GetType() , $array1.GetType(),$array2.GetType(),$array4.GetType()| Select Module,Assembly,TypeHandle,BaseType,UnderlyingSystemType,FullName,AssemblyQualifiedName,Namespace,CustomAttributes | FT


#Pushing complex objects
#Here get a JSON dump of the group info and compress it so each JSON object is one line of text
#$JSONDump = Get-ADGroupMember SET-PhoneNumberInDisplayName | Select SamAccountName,SID, distinguishedName | Foreach-object {($_ | ConvertTo-Json).tostring() -replace "`n|`r" }
$JSONDump = Get-ADGroupMember SET-PhoneNumberInDisplayName | Select SamAccountName,SID, distinguishedName | ConvertTo-Json -Compress -Depth 1
#Now we push the JSON object to the multivalued attribute
Set-ADGroup -Identity SET-PhoneNumberInDisplayName -replace @{msExchExtensionCustomAttribute2=$JSONDump} -ErrorAction stop
#Show that the JSON object is in the multivalued attribute
Get-ADGroup -Identity SET-PhoneNumberInDisplayName -Properties msExchExtensionCustomAttribute2
(Get-ADGroup -Identity SET-PhoneNumberInDisplayName -Properties msExchExtensionCustomAttribute2).msExchExtensionCustomAttribute2
#Now convert it back to JSON
(Get-ADGroup -Identity SET-PhoneNumberInDisplayName -Properties msExchExtensionCustomAttribute2).msExchExtensionCustomAttribute2 | ConvertFrom-Json


#You can also use a single value attribute to store a flat CSV
#Here we create string of samaccountnames joined by commas
$CSV = (Get-ADGroupMember SET-PhoneNumberInDisplayName | Select-Object -ExpandProperty SamAccountName) -join ","
#Now we push it to the single value attribute
Set-ADGroup -Identity SET-PhoneNumberInDisplayName -replace @{msExchExtensionAttribute45=$CSV} -ErrorAction stop
#Show the string in the single value attribute
Get-ADGroup -Identity SET-PhoneNumberInDisplayName -Properties msExchExtensionAttribute45
(Get-ADGroup -Identity SET-PhoneNumberInDisplayName -Properties msExchExtensionAttribute45).msExchExtensionAttribute45
#Pull the object and Split it
(Get-ADGroup -Identity SET-PhoneNumberInDisplayName -Properties msExchExtensionAttribute45).msExchExtensionAttribute45 -split ","