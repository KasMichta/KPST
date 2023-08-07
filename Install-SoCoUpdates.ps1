# This script deploys Windows Feature Updates in the background without rebooting the devices while users are logged in

# Function to check if any user is logged in
function IsUserLoggedIn {
	$loggedInUser = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
	return (![string]::IsNullOrEmpty($loggedInUser))
}

# Array of Category IDs to search for updates
$categoryIDs = @(
	'e6cf1350-c01b-414d-a61f-263d14d133b4' # Critical Updates
	'e0789628-ce08-4437-be74-2495b842f43b' # Definition Updates
	'b54e7d24-7add-428f-8b75-90a396fa584f' # Feature Packs
	'0fa1201d-4330-4fa8-8ae9-b877473b6441' # Security Updates
	'28bc880e-0592-4cbf-8f95-c79b17911d5f' # Update Rollups
	'cd5ffd1e-e932-4e3a-bf74-18bf0b1bbd83' # Updates
	'3689bdc8-b205-4af4-8d4a-a63924c5e9d5' # Upgrades
)

# Search and download updates
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $UpdateSession.CreateUpdateSearcher()

$updates = New-Object System.Collections.ArrayList

$searchQueries = New-Object System.Collections.ArrayList

foreach ($categoryID in $categoryIDs) {
	[void]$searchQueries.add("(IsInstalled=0 and CategoryIDs contains '$categoryID')")
}

$searchString = $searchQueries -join ' or '

$searchResult = $UpdateSearcher.Search($searchString)

$updates = $searchResult.Updates

# If there are Updates available, proceed with the installation process
if ($Updates.count -gt 0) {

	foreach ($Update in $Updates) {
		# Create an Update Collection to store update to be installed
		$UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

		Write-Output "$($Update.Title) - Attempting Install"
		$UpdatesToInstall.Add($Update) | Out-Null

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
		elseif ($InstallResult.ResultCode -eq 3) {
			Write-Output '----Install Successful !WITH ERRORS!----'
		}
		elseif ($InstallResult.ResultCode -eq 4) {
			Write-Output '!!!!FAILED UPDATES!!!!'
		}
		elseif ($InstallResult.ResultCode -eq 5) {
			Write-Output '!!!!ABORTED UPDATES!!!!'
		}
		else {
			Write-Output 'Error with retrieving result of installation'
		}
	}
}
else {
	Write-Output 'No relevant updates are available.'
}