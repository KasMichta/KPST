Function Get-OSSupportStatus {

    $OSEOLs = Invoke-RestMethod -Method Get -Uri https://endoflife.date/api/windows.json

    $Version = @{l = "Version"; e = { $_.OSVersion } }
    $Edition = @{l = "Edition"; e = { if ($_.OsOperatingSystemSKU -match "Ent|iot") { "E" }else { "W" } } }
    $OS = Get-ComputerInfo | Select-object -Property $Version, $Edition, OSName

    Write-Output "OS Detected: $($OS.OSName)"
    Write-Output "OS Version: $($OS.Version)"

    $MatchingOS = $OSEOLs | Where-Object {
    ($_.cycleshorthand -eq $OS.Version) -and 
    ($($_.cycle | Select-String -Pattern '\((?<ed>E|W)\)' -AllMatches | Set-Variable Editions ; $Editions.Matches.Groups.where({ $_.name -eq "ed" }).value) -contains $OS.Edition) }

    $eoldate = Get-Date $MatchingOS.eol
    $OSSupported = (Get-Date) -lt $eoldate

    If ($OSSupported) {
        Write-Output "OS Supported"
    }
    else {
        Write-Output "OS is EOL"
    }

}

Get-OSSupportStatus