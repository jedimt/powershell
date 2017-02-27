#solidfire-create-satp-v1.ps1
#created by Aaron Patten @Jedimt

#This script will create a SolidFire specific SATP for any *NEW* devices
#If its run after SF devices have been presented, you will need to reboot
#in order to get the devices claimed by the new SATP.
#If you can't reboot, you can run the 'fixnmp.ps1' script which should make
#the change online, but the reboot is preferred method.
#this will prompt for credentials to your vCenter server
#####################################################################
#<vcenter-variables>
$creds = Get-Credential
$vcenter = "vmvcsa01.ts.local"
$cluster = "Dell-Prod"
$IOOperationsLimit = "8"
#</vcenter-variables>

#Connect to vCenter
write-host "Connecting to vCenter server" $vcenter
Connect-VIServer -Server $vcenter -Credential $creds
$hosts = get-cluster $cluster | get-vmhost

foreach ($esx in $hosts) 
     {
         #This sets up a connection to the local $esxcli instance on each ESXi server
         write-host "`nConnecting to host:" $esx
         $esxcli = get-esxcli -VMHost $esx -v2
         
         #Set a default SATP for SolidFire devices named "SolidFire Custom SATP"
         #This will claim all NEW SolidFire devices
         #Sets default PSP to "VMW_PSP_RR" (Round Robin) for any SolidFire Device
         #Sets default SATP to "VMW_SATP_DEFAULT_AA" for any SolidFire Device
         #Sets iops=8 -> every other IO will go down any available path to a naa device. Default is 1000
         #Will require a reboot if SolizdFire devices already presented to the host

        $SFSATP = $esxcli.storage.nmp.satp.rule.remove.createArgs()
        $SFSATP.description = "SolidFire Custom SATP"
        $SFSATP.model = "SSD SAN"
        $SFSATP.vendor = "SolidFir"
        $SFSATP.satp = "VMW_SATP_DEFAULT_AA"
        $SFSATP.psp = "VMW_PSP_RR"
        $SFSATP.pspoption = $IOOperationsLimit
        
        Write-Host "Checking to see if there is an existing SATP rule"
        $checkSATP = $esxcli.storage.nmp.satp.rule.list.Invoke() | Where-Object {$_.Vendor -eq "SolidFir"}

        If (!$checkSATP) {
            write-host "Creating SATP for SolidFire devices"
            $esxcli.storage.nmp.satp.rule.add.invoke($SFSATP)
            } else {
            Write-Host "Custom SolidFire SATP already present on system"
            Write-Host $esx.Name
            Write-Host ($checkSATP | FT -AutoSize | Out-String)

        }
}