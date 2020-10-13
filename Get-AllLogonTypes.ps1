#requires -version 7
<#
.SYNOPSIS
	Get-AllLogonTypes.ps1
	Gets all account logon types for an entire domain.

.DESCRIPTION
	This script queries every domain server and parses info from all 4624 Successful Logon events.
	It takes that info and stores it a individual csv files for each server.
	It then imports each csv and merges all the data into single csv file that can be used to assess and audit
	your User Rights Assignments for our entire domain.

	This is useful when you have taken over old, legacy domains with excessive legacy user accounts and
	no documentation for User Rights Assignments such as 'Log on as a batch job' and
	'Log on as a service'.



.INPUTS
	None

.OUTPUTS
	Default - C:\temp\*.csv

.NOTES
	Version:		1.0
	Author:			Leon Evans
	Creation Date: 	13/10/2020
	Location:		https://github.com/Guyver1wales/Get-AllLogonTypes
	Change Log:
	v1.0
	Original Version

#>

#* ---------------------------------------------------------
#* INITIALISATIONS
#* ---------------------------------------------------------
#*	1> define initialisations and global configurations
#*	2> list dot Source required Function Libraries
#region initialisations

#endregion

#* ---------------------------------------------------------
#* DECLARATIONS
#* ---------------------------------------------------------
#*	3> define and declare variables here
#*	All variables to conform to the lowerCamelCase format:
#*	e.g. $scriptVersion = '1.0', $fileName = 'output.txt'
#region declarations

#DEFINE SERVER LIST TO QUERY #
$servers = (Get-ADComputer `
		-Properties Name, Operatingsystem, DistinguishedName `
		-Filter 'OperatingSystem -like "Windows Server*" -and Enabled -eq $true' |
		Sort-Object -Property Name).Name

# ALTERNATIVE TO SPECIFY ARRAY OF SERVERS BY NAME #
#[arraay]$servers = 'server1','server2','server3'

#endregion

#* ---------------------------------------------------------
#* FUNCTIONS
#* ---------------------------------------------------------
#*	4> primary functions and helpers should be abstracted here
#region functions

#endregion

#* ---------------------------------------------------------
#* EXECUTION
#* ---------------------------------------------------------
#*	6> execution, actions and callbacks should be placed here
#region execution

$servers | ForEach-Object -ThrottleLimit 10 -Parallel {
	# P7 ARG[0] STORE OUTPUT FILES HERE #
	$folderPath = 'C:\Temp'
	# P7 ARG[1] DEFINE SERVERNAME #
	$servername = "$_"

	# CHECK FOR EXISTING OUTPUT FILE PER SERVER #
	if ($(Test-Path -Path "$folderPath\$($_)-logonTypes.csv") -eq $true) {
		exit
	}
	else {
		Write-Host "Processing $servername $(Get-Date)" -ForegroundColor Green -BackgroundColor DarkBlue

		# PROCESS EACH SERVER USING A SEPARATE POWERSHELL 7 INSTANCE TO MINIMISE MEMORY USAGE #
		& "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -args $servername, $folderPath -Command {
			try {
				# QUERY THE SECURITY LOG FOR ALL 4624 EVENTS AND STORE AS VARIABLE #
				$accountLogons = (Get-WinEvent -ComputerName "$($args[0])" -FilterHashtable @{
						Logname = 'Security'
						ID      = '4624'
					} -WarningAction Stop -ErrorAction Stop)

				# CREATE CUSTOM OBJECTS FROM ALL SERVERS AND STORE AS VARIABLE #
				$results = foreach ($i in $accountLogons) {
					[PSCustomObject]@{
						ComputerName  = $i.MachineName
						LogonType     = $i.Properties[8].Value
						SecurityID    = $i.Properties[4].Value
						AccountName   = $i.Properties[5].Value
						AccountDomain = $i.Properties[6].Value
					}
				}

				# FILTER ALL RESULTS FOR UNIQUE ENTRIES AND EXPORT TO CSV #
				$results | Select-Object -Property `
					ComputerName, `
					LogonType, `
					SecurityID, `
					AccountName, `
					AccountDomain `
					-Unique |
					Export-Csv -Path "$($args[1])\$($args[0])-logonTypes.csv" -NoTypeInformation

					Write-Output -InputObject "Completed $($args[0]) $(Get-Date)"
					exit
				}
				catch {
					Write-Error -Message "could not connect to $($args[0])"
					exit
				}
			}
		}
	}

	# COMBINE ALL SERVER OUTPUT FILES INTO ONE FINAL MERGED OUTPUT FILE #
	$outputPath = 'C:\Temp'
	$files = (Get-ChildItem -Path "$outputPath\*" -Include *.csv).FullName

	$finalFile = $files | ForEach-Object -ThrottleLimit 10 -Parallel {
		Import-Csv -Path $($_)
	}

	$finalFile | Sort-Object -Property ComputerName, LogonType | Export-Csv -Path "$outputPath\ALL-SERVERS-ALL-LOGON-TYPES.csv" -NoTypeInformation


	#endregion
