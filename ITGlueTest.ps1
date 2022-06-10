
Function Sent-BLtoITG {

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $OrgID,
        [Parameter()]
        [string]
        $APIKey
    )

    $APIEndpoint = "https://api.eu.itglue.com"

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("X-API-KEY", "$APIKey")
    $headers.Add("Content-Type" , 'application/vnd.api+json')

    $localserial = $null
    $localserial = (get-ciminstance win32_bios).serialnumber

    If (!($localserial) -or ($localserial.Length -lt 2)) {
        Write-Host "No Serial Number found on machine"
    }
    else {
        $Configs = Invoke-RestMethod -Uri "$APIEndpoint/organizations/$Orgid/relationships/configurations?filter[serial_number]=$localserial" -Method Get -Headers $headers
        $TaggedResource = $Configs.data | Select-Object -First 1
    }
    Write-Output $TaggedResource

}