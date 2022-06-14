Function Get-BitlockerStatus {

    try {
        $BL = Get-BitLockerVolume -MountPoint C:

        switch -wildcard ("$($BL.VolumeStatus) - $($BL.ProtectionStatus)") {
            "FullyEncrypted - On" { Write-Output "Protection On" }
            "FullyEncrypted - Off" { Write-Output "Protection Off" }
            "EncryptionInProgress*" { Write-Output "In Progress" }
            Default { Write-Output "Bitlocker Volume not fully encrypted." }
        }

    }
    catch {
        Write-Output "Error: Failed to retrieve Bitlocker Volume status `n...Investigate results of 'Get-BitlockerVolume' cmdlet."
    }
}

Function Get-BLRP {
    ((Get-BitLockerVolume -MountPoint "C:").Keyprotector | Where-Object Keyprotectortype -eq "RecoveryPassword" | Select-Object -First 1).RecoveryPassword
}

Function Send-ToITGlue {

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $OrgID,
        [Parameter()]
        [string]
        $APIKey,
        [Parameter()]
        [string]
        $RecoveryPass
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("X-API-KEY", "$APIKey")
    $headers.Add("Content-Type" , 'application/vnd.api+json')

    $APIEndpoint = "https://api.eu.itglue.com"
    $PasswordObjectName = "$($Env:COMPUTERNAME) - C:"

    # Check if password for device already exists
    $PassName = Invoke-RestMethod -Uri "$APIEndpoint/organizations/$Orgid/relationships/passwords?filter[name]=$PasswordObjectName&filter[archived]=false" -Method Get -Headers $headers

    # Get local serial number - used later to add 'related item' to password.
    $localserial = (get-ciminstance win32_bios).serialnumber

    If (!($localserial) -or ($localserial.Length -lt 2)) {
        Write-Output "No Serial Number found on machine"
    }
    else {
        #Find configuration in IT Glue with same serial as local machine
        $Configs = Invoke-RestMethod -Uri "$APIEndpoint/organizations/$Orgid/relationships/configurations?filter[serial_number]=$localserial" -Method Get -Headers $headers
        $TaggedResource = $Configs.data | Select-Object -First 1
    }

    $body = @{
        data = @{
            type       = 'passwords'
            attributes = @{
                name                   = $PasswordObjectName
                password               = $RecoveryPass
                notes                  = "Bitlocker key for $($Env:COMPUTERNAME)"
                'password-category-id' = "1380901820596386"
    
            }
        }
    } 
        
    # If config was found above, then create the password with the link to it
    If ($TaggedResource) { 
        $Body.data.attributes.Add("resource_id", $TaggedResource.Id)
        $Body.data.attributes.Add("resource_type", "Configuration")
    }
    
    $body = $body | convertto-json -depth 4

    if ($PassName.data.Count -eq 0) {
        # No passwords found, therefore create
        Write-Output "Creating new IT Glue record."
        Invoke-RestMethod -Uri "$APIEndpoint/organizations/$Orgid/relationships/passwords" -Method POST -Body $body -Headers $headers 

    }
    elseif ($PassName.data.Count -eq 1) {
        $PassID = $PassName.data.id
        $PasswordContent = Invoke-RestMethod -Uri "$APIEndpoint/organizations/$Orgid/relationships/passwords/$PassID" -Method Get -Headers $headers
        
        # If Password in IT Glue same as local
        if ($($PasswordContent.data.attributes.password.trim()) -eq $RecoveryPass) {
            Write-Output "IT Glue Record already contains correct password."
        }
        else {
            # Update password in IT Glue
            Write-Output "Updating existing IT Glue record with new password."
            Invoke-RestMethod -Uri "$APIEndpoint/organizations/$Orgid/relationships/passwords/$PassID" -Method Patch -Body $body -Headers $headers 
        }


    }else{
        $PassID = $PassName.data.id | Select-Object -First 1
        Write-Output "More than 1 Existing IT Glue record found. Updating first result (ITGlueID: $PassID)"
        Write-Output "Please Archive/Duplicate duplicate records:"
        $PassName.data.id | Select-object -Skip 1| ForEach-Object {Write-Output "$_"}
        $PasswordContent = Invoke-RestMethod -Uri "$APIEndpoint/organizations/$Orgid/relationships/passwords/$PassID" -Method Get -Headers $headers
        
        # If Password in IT Glue same as local
        if ($($PasswordContent.data.attributes.password.trim()) -eq $RecoveryPass) {
            Write-Output "IT Glue Record already contains correct password."
        }
        else {
            # Update password in IT Glue
            Write-Output "Updating existing IT Glue record with new password."
            Invoke-RestMethod -Uri "$APIEndpoint/organizations/$Orgid/relationships/passwords/$PassID" -Method Patch -Body $body -Headers $headers 
        }
    }
    

}


$status = Get-BitlockerStatus 

# If status shows:
## Protection On 
#### -> Get Recovery Key
## Protection Off
#### -> Get Recovery Key
#### -> Turn On Protection
## Encryption in Progress
#### -> Get Recovery Key
## Not Encrypted
#### -> Encrypt C Drive
#### -> Turn On Protection
#### -> Get Recovery Key
## Error
#### Error message
switch ($status) {
    "Protection On" {
        $RecoveryPass = Get-BLRP

        Write-Output "Protection is Enabled"
    }
    "Protection Off" {
        $RecoveryPass = Get-BLRP
        Try {
            Manage-BDE -on C:
            Write-Output "Protection was disabled, Enabling Protection..."
        }
        catch {
            Write-Output "Could not enable Protection"
        }

    }
    "In Progress" {
        $RecoveryPass = Get-BLRP
        Write-Output "Encryption In Progress"
    }
    "Bitlocker Volume not fully encrypted." {
        Enable-BitLocker -MountPoint C: -EncryptionMethod Aes128 -SkipHardwareTest -UsedSpaceOnly -RecoveryPasswordProtector
        Manage-BDE -on C:
        $RecoveryPass = Get-BLRP
    }
    Default {
        Write-Output "Error: Could not retrieve Bitlocker Status"
    }
}

if ($RecoveryPass) {
    Try {
        Write-Output "Sending Recovery password to IT Glue..."
        Send-ToITGlue -OrgID $Orgid -APIKey $APIKey -RecoveryPass $RecoveryPass
    }
    catch {
        Write-Output "Could not send password to IT Glue."
    }

    Write-Output "Recovery Password: $RecoveryPass"

}

