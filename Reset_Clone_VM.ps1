#
# Purpose: This script reverts VMs to a snapshot and 
#              powers them ON after the revert for the specified pods.
#          It also resets the Client VMs.
#          The task runs async, which means that the script will issue the command and will not wait for it to finish.
#
###############################################################################################################
#          HOW TO EXECUTE - RIGHT CLICK AND RUN WITH POWERSHELL TO EXECUTE THE SCRIPT
###############################################################################################################

$global:v = "x.x.x.x"
$global:u = "username"
$global:p = "password"

$PODLOW = 1      # DO NOT MODIFY THESE, JUST RIGHT CLICK AND RUN WITH POWERSHELL TO EXECUTE THE SCRIPT 
$PODHIGH = 10    # DO NOT MODIFY THESE, JUST RIGHT CLICK AND RUN WITH POWERSHELL TO EXECUTE THE SCRIPT 

function reset_the_vms ($processedpodlist) {

	#Start-Process -FilePath 'C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Launcher\VpxClient.exe' -ArgumentList "-s $global:v -u $global:u -p $global:p"
	
	Connect-VIServer -Server $global:v -User $global:u -Password $global:p
	

	

	$VM_TO_BE_RESET = "9800-CL1","DC-CSR1K-NAT","Wired-EMP1","WLC-Guest"  # Do not put the pod prefix here. The script will assume that there is pod prefix

	foreach ($_ in $processedpodlist) {
		$podno = $_
		"`n------------------------`n`n" + "==> WORKING on resetting VMs such as ISE, websrv, clients etc ON POD - " + $podno + " now. Please be patient"
		
		$VM_TO_BE_RESET | foreach {
			$VM_name= "P" + $podno + "-" + $_
			Stop-VM -VM $VM_name -confirm:$false | out-null
		}
		$VM_TO_BE_RESET | foreach {
			$VM_name= "P" + $podno + "-" + $_
			Start-VM -VM $VM_name -confirm:$false -RunAsync | out-null
		}
	}


    $VM_TO_BE_RESET = "ISE-T1"  # Do not put the pod prefix here. The script will assume that there is pod prefix

	foreach ($_ in $processedpodlist) {
		$podno = $_
		"`n------------------------`n`n" + "==> Powering Off and Deleteing ISE VM ON POD - " + $podno + " now. Please be patient"
		
		$VM_TO_BE_RESET | foreach {
			$VM_name= "P" + $podno + "-" + $_
			Stop-VM -VM $VM_name -confirm:$false | out-null
			Start-Sleep -Seconds 2
			Remove-VM -VM $VM_name -DeletePermanently -confirm:$false
		}
	}

	$VM_TO_BE_CLONED = "ISE-BASE"  # Do not put the pod prefix here. The script will assume that there is pod prefix
	$SNAPSHOT_NAME = "BASE-LAB" # Provide a unique name for the snapshot

	foreach ($_ in $processedpodlist) {
		$podno = $_
		$VM_name= "P" + $podno + "-" + $VM_TO_BE_CLONED
		$New_VM_name= "P" + $podno + "-" + "ISE-T1"
		$New_VM_datastore= "data" + "-" +"ISE" + "-" + "1" + $podno
        $New_VM_host= "10" + "." + "12" + "." + "1" + "." + 1 + $podno

		"`n------------------------`n`n" + "==> WORKING on cloning ISE VM ON POD - " + $podno + " now"
		
		Start-Sleep -Seconds 2
		New-VM -name $New_VM_name -vm $VM_name -datastore $New_VM_datastore -vmhost $New_VM_host -DiskStorageFormat thin -RunAsync | out-null
		Start-Sleep -Seconds 4
		Start-VM -VM $New_VM_name -confirm:$false -RunAsync | out-null
	}		
}


function printpodlist ($podlist) {
	$output = ''
	$range = $PODLOW..$PODHIGH
	foreach ($x in $range) {
		if ($x.tostring().PadLeft(2,'0') -in $podlist) {
			$output = $output + $x.tostring().PadLeft(2,'0')
		}
		else {
			$output = $output + '--'
		}
		if ($x%10 -eq 0 -and $x -ne $PODHIGH) {
			$output = $output + "`n`n"
		}
		else {
			$output = $output + "    "
		}
	}
	$output
}

function getpodnumbersfromlist ($podlist) {
	$podlist = $podlist -replace ("\s+", "")
	$array1 = $podlist.split(',')
	
	$array2 = @()
	foreach ($a in $array1) {
		if ($a -eq '') {
			continue
		}
		$x = $a |  Select-String -Pattern '[^0-9-]' -AllMatches
		if ($x -and $x.length -gt 0) {
			continue
		}
		$x = $a | Select-String -Pattern '[-]' -AllMatches
		if ($x -and $x.length -gt 1) {
			continue
		}
		$y = $a.split('-')
		if ($y.length -lt 3) {
			if ($y.length -eq 1 -and $y[0] -ne "")
			{	$array2 += [int]$y[0]	}
			elseif ( $y.length -eq 2 -and $y[0] -ne "" -and $y[1] -ne "")
			{	$array2 += [int]$y[0]..([int]$y[1])	}
		}
	}
	
	$array3 = $array2 | select -uniq
	$array3 = $array3 | sort
	
	$processedpodlist = @()
	foreach ($a in $array3) {
		if ($a -ge $PODLOW -and $a -le $PODHIGH)
		{	$processedpodlist += $a.tostring().PadLeft(2,'0')	}
	}
	
	return $processedpodlist
}

function initial_user_interaction() {
	$p = '100 , 2 - 5, 10, 10  , a, 10-14'

	"`nWELCOME TO THE ISE, JUMPHOST, SERVER VMs AND CLIENT VMs RESET UTILITY!`n"
	$rawpodlist = Read-Host -Prompt "What all Pod VMs would you like to reset? (For example - 1, 4-6, 10) "
	$processedpodlist = getpodnumbersfromlist($rawpodlist)

	while ( $processedpodlist.length -eq 0) {
		$rawpodlist = Read-Host -Prompt "`nIt seems you did not enter the pod numbers in the required format. Let's try again - \n What all Pod VMs you would like to reset? (For example - 1, 4-6, 10) "
		$processedpodlist = getpodnumbersfromlist($rawpodlist)
	}

	"`nBased on your input I could parse the following pod numbers:"
	printpodlist($processedpodlist)
	
	$confirmation1 = ''
	while (1) {
		if ($confirmation1 -ne 'Y' -and $confirmation1 -ne 'N' -and $confirmation1 -ne 'y' -and $confirmation1 -ne 'n')
		{	$confirmation1 = Read-Host -Prompt "`nAre you OK to initiate RESET of ISE, JUMPHOST, SERVER VMs AND CLIENT VMS on the above pods? (Y/N) "	}
		else
		{	break	}
	}
	
	$confirmation2 = ''
	if ($confirmation1 -ne 'N' -and $confirmation1 -ne 'n') {
		"`nKINDLY CONFIRM ONCE AGAIN as there is no going back."
		while (1) {
			if ($confirmation2 -ne 'Y' -and $confirmation2 -ne 'N' -and $confirmation2 -ne 'y' -and $confirmation2 -ne 'n')
			{	$confirmation2 = Read-Host -Prompt " Are you surely OK to initiate RESET of ISE, JUMPHOST, SERVER VMs AND CLIENT VMS on the above pods? (Y/N) "	}
			else
			{	if ($confirmation2 -ne 'N' -and $confirmation2 -ne 'n')
				{	reset_the_vms($processedpodlist)
					"`nTHANK YOU for using this utility!"
					Read-Host -Prompt "`nPress Enter to exit! "
				}
				break
			}
		}
	}
	else {
		"`nTHANK YOU for using this utility!"
		exit
	}
	
	if ($confirmation2 -eq 'N' -or $confirmation2 -eq 'n')
	{	"`nTHANK YOU for using this utility!"
		exit
	}
}

initial_user_interaction