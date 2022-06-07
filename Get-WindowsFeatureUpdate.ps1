if (!(Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue)){
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
}

if (!(Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue)) {
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
}
else {
    Import-Module -Name PSWindowsUpdate
}

Install-WindowsUpdate -Title "Feature Update" -AcceptAll -Install -IgnoreReboot -IgnoreRebootRequired -Confirm:$false

