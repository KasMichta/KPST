# Selects drives over 20GB in size, this 
$size = 20GB

$volumes = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "Size > $Size"

foreach ($volume in $Volumes){
    $driveLetter = $volume.DeviceID
    $freeGB = [Math]::round($volume.FreeSpace / [Math]::Pow(1024,3), 1);
    If ($volume.FreeSpace/$volume.Size -lt 0.1){
        Write-Output "FAIL: Drive $driveLetter - $freeGB GB remaining (<10% of drive size)"
    } else{
        Write-Output "Drive $driveLetter - OK - $freeGB GB remaining (>10% of drive size)"
    }
}
