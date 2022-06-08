Function Get-BitlockerStatus {

    try {
        Get-childitem C:\ProgramData\Microsoft\DMClient -ErrorAction Stop | Select-Object -First 1 -ExpandProperty name | Set-Variable guid

        if ($guid){
            Write-Output "Machine is enrolled in Intune"
        }else{
            Write-Output "Unexpected: DMClient Folder found but no Enrollment GUID found"
        }
    }
    catch [System.Management.Automation.ItemNotFoundException]{
        Write-Output "No Intune Enrollment ID found"
    }

}

Get-BitlockerStatus

