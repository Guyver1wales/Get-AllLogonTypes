$accountLogons = (Get-WinEvent `
		-Path "C:\temp\Security.evtx" `
		-FilterXPath 'Event[System[EventID=4624]]')

$results = foreach ($i in $accountLogons) {
	[PSCustomObject]@{
		ComputerName  = $i.MachineName
		LogonType     = $i.Properties[8].Value
		SecurityID    = $i.Properties[4].Value
		AccountName   = $i.Properties[5].Value
		AccountDomain = $i.Properties[6].Value
	}
}

#! MODIFY OUTPUT FILE NAME #
$results | Select-Object -Property `
	ComputerName, `
	LogonType, `
	SecurityID, `
	AccountName, `
	AccountDomain `
	-Unique |
	Export-Csv -Path "C:\temp\<servername>-logonTypes.csv" -NoTypeInformation
