# This script deploys Windows Feature Updates in the background without rebooting the devices while users are logged in

# Function to check if any user is logged in
function IsUserLoggedIn {
	$loggedInUser = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
	return (![string]::IsNullOrEmpty($loggedInUser))
}

# Check if a user is logged in
$userLoggedIn = IsUserLoggedIn

# If no user is logged in, proceed with the update process

# Search and download updates
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
$SearchResult = $UpdateSearcher.Search('IsInstalled=0')


$Updates = New-Object System.Collections.ArrayList

# Filter for Feature Updates
$SearchResult.Updates | Where-Object { $_.Title -match 'Feature update to Windows' } | ForEach-Object { [void]$Updates.add($_) }
# Filter for Critical, Security, Rollup, and Definition updates
$SearchResult.Updates | Where-Object { $_.Categories | Where-Object { $_.Name -match 'Critical|Security|Update rollup|Definition' } } | ForEach-Object { [void]$Updates.add($_) }

# If there are Updates available, proceed with the installation process
if ($Updates) {
	# Create an Update Collection to store updates to be installed
	$UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

	# Add Feature Updates to the Update Collection
	foreach ($Update in $Updates) {
		Write-Output "$($Update.Title) - Attempting Install"
		$UpdatesToInstall.Add($Update) | Out-Null
	}

	# Download updates
	$Downloader = $UpdateSession.CreateUpdateDownloader()
	$Downloader.Updates = $UpdatesToInstall
	$DownloadResult = $Downloader.Download()

	# Install updates
	$Installer = $UpdateSession.CreateUpdateInstaller()
	$Installer.Updates = $UpdatesToInstall
	$InstallResult = $Installer.Install()

	# Reboot the device if the installation was successful and no user is logged in
	if ($InstallResult.ResultCode -eq 2 -and !(IsUserLoggedIn)) {
		Write-Output '----Install Successful----'
		Try {
			Restart-Computer -ErrorAction Stop
		}
		Catch [System.InvalidOperationException] {
			Write-Output 'User Logged in, Reboot cancelled.'
		}
		Catch {
			Write-Output 'Cannot Reboot Device'
		}
		Write-Output 'Updates Installed, User Not Logged in - Rebooting...'
		
	}
 elseif ($InstallResult.ResultCode -eq 2 -and (IsUserLoggedIn)) {
		Write-Output '----Install Successful----'
		Write-Output 'User Logged in, Reboot cancelled.'
	}
	else {
		Write-Output '!!!-Install Unsuccessful-!!!'
	}
}
else {
	Write-Output 'No relevant updates are available.'
}