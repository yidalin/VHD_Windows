# Reference: https://stackoverflow.com/questions/16903460/bcdedit-bcdstore-and-powershell
# Create new user by current boot entry description
$CurrentBootEntryDescription = bcdedit /enum |
    Select-String -Pattern "identifier.*current" -Context 0,3 |
    ForEach-Object { $_.Context.PostContext[2] -replace '^description +' }
$NewUser = $CurrentBootEntryDescription
$Password = ConvertTo-SecureString $NewUser -AsPlainText -Force
New-LocalUser -Name $NewUser -Description $NewUser -AccountNeverExpires -Password $Password -PasswordNeverExpires
Add-LocalGroupMember -Group administrators -Member $CurrentBootEntryDescription