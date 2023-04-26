Function Get-OSSupportStatus {

    $OSEOLs = Invoke-RestMethod -Method Get -Uri https://endoflife.date/api/windows.json

    $Version = @{l = 'Version'; e = { $_.OSVersion } }
    $Edition = @{l = 'Edition'; e = { if ($_.OsOperatingSystemSKU -match 'Ent|iot|Edu') { 'E' }else { 'W' } } }
    $OS = Get-ComputerInfo | Select-Object -Property $Version, $Edition, OSName

    if (($null -eq $OS.Version) -or ($null -eq $OS.OSName)) {
        Write-Output 'System failed to retrieve OS version or OS name. Likely needs updates or reboot.'
    }
    else {

        Write-Output "OS Detected: $($OS.OSName)"
        Write-Output "OS Version: $($OS.Version)"

        $pattern = '\({0}\)' -f $os.Edition
        $MatchingOS = $OSEOLs | Where-Object {
            ($_.latest -eq $OS.Version) -and 
            ($_.cycle -match $pattern) 
        }

        $eoldate = Get-Date $MatchingOS.eol
        # Trigger if EOL is within 2 months
        $OSSupported = (Get-Date) -lt $eoldate.AddMonths(-2)

        If ($OSSupported) {
            Write-Output 'OS Supported'
        }
        else {
            Write-Output 'OS is EOL'
        }
    }
}

Get-OSSupportStatus