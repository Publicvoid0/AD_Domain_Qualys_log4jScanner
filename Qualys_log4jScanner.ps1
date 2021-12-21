<#
.DESCRIPTION
   	Execute this script on all servers on the domain
    This script was a bit rushed and can probably be improved on 
    Download the Log4jScanner.exe from https://github.com/Qualys/log4jscanwin  or https://github.com/Qualys/log4jscanwin/releases/download/1.2.17/Log4jScanner-1.2.17.zip
    
.NOTES
    Must be run by an Administrator/Workstation Administrator to access Windows Remote Management
    The must be run on a Domain Controller or have the ActiveDirectory PowerShell module installed to enumerate computer accounts

#>

Start-Transcript -Path $($env:temp + "\Qualys_log4j_detect.log")

Try {
    $ErrorActionPreference = "SilentlyContinue"
    $results = ""


    If (!(Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory
    }
    $servers = Get-ADComputer -Filter {(OperatingSystem -like "* server *") -and (Enabled -eq "True")} -Properties OperatingSystem | Sort Name | select -Unique Name
	
	
	$Creds = Get-Credential -Message "Admin Credential are required to run this script."
	$sourcefile = "\\SERVERNAME\c$\Temp\log4j_script\Log4jScanner.exe"
	$sourcescript = "\\SERVERNAME\c$\Temp\log4j_script\detect.ps1"
  $file = "C:\temp\Log4jScanner.exe" 
	$temp = "C:\temp"

	foreach ($server in $servers) {
        #Write-Host $server.name
        $result = "$($server.name), OFFLINE"
        $PingResult = Get-WmiObject -Query "SELECT * FROM win32_PingStatus WHERE address='$($server.Name)'" 
        If ($PingResult.StatusCode -eq 0) {
        Try {
			   $session = New-PSSession -ComputerName $server.name -Credential $Creds
                If (Invoke-Command -Session $session -ScriptBlock {Test-Path -path $args[0]} -ArgumentList $temp) 
				{
				#Write-Host "C:\temp exists"
				}            
				Else {
						#Write-Host "Path does NOT exist $server.name"
						Invoke-Command -Session $session -ScriptBlock {New-Item C:\temp -type directory -force} 
					}
                Copy-Item -Path $sourcefile -Destination $temp -ToSession $session
                Copy-Item -Path $sourcescript -Destination $temp -ToSession $session
				        $command = { powershell.exe C:\temp\Log4jScanner.exe /scan /report_sig}
                $out = Invoke-Command -ComputerName $server.name -ScriptBlock $command
                Remove-PSSession -Session $session
                #Write-host $out
                Write-Host "PS_Script_Executed on" $server.name
            } 
            Catch {
                Write-Error $_
            }
        }
        $results += "$result`n"
    }
} Catch {
    Write-Error $_
} Finally {
    Stop-Transcript
}
