<#
.SYNOPSIS
	Create a number of replication jobs for VEEAM v9.5

.DESCRIPTION
	With this script you can create a lot of single VM replication jobs at once. 
	See http://www.GabesVirtualWorld.com/ for a more details.
	
.NOTES
  Version: 1.0
  Authors: Gabrie van Zanten http://www.GabesVirtualWorld.com and Joren De Spaey
  Authors: Annelies Maex https://be.linkedin.com/in/anneliesmaex
  Authors: Joren De Spaey https://www.linkedin.com/in/jorendespaey
  Creation Date:  18 jan 2017
  Github: https://github.com/TheGabeMan/Veeam-Replication

#>

# Load the VEEAM PowerShell Snapin
Add-PSSnapin VeeamPSSnapin

<#
.SETTINGS	
	# See for specific options: https://helpcenter.veeam.com/docs/backup/powershell/add-vbrvireplicajob.html?ver=95
#>


<#	
	-Suffix : Specifies the suffix that will be appended to the name of the VM you are replicating. 
	This name will be used to register the replicated VM on the target server. Default: "_replica".
 	We want suffix to be empty to prevent being stuck with _replica in the name after the migration
#>
$Suffix = " "

<#
	Restore Points ToKeep: Specifies the number of restore points you want to keep. Permitted values: 1 to 28. Default: 7.
#>
$RestorePoints = 1

<#	Source & Target ESXi host: Since the PortGroups (Networks) for Networkmappings are read from an ESXi host and not from vCenter,
	we need an ESXi host to talk to on each side.
#>
$SourceESXi = "esx001.source.local"
$TargetESXi = "esx-aaa.target.local"

<#	
	Source Proxy: Specifies the source proxy you want to assign to the job. Default: automatic selection.
	Target Proxy: Specifies the target proxy you want to assign to the job. Default: automatic selection.
	Retreive proxies using: get-vbrviproxy -name "sourceproxy1"
#>

$ObjSourceProxy = @()
$ObjSourceProxy += Get-VBRViProxy -name "sourceproxy1"
$ObjSourceProxy += Get-VBRViProxy -name "sourceproxy2"

$ObjTargetProxy = @()
$ObjTargetProxy += Get-VBRViProxy -name "targetproxy1"
$ObjTargetProxy += Get-VBRViProxy -name "targetproxy2"

<#
	Import the network mapping of source portgroup to target portgroup
	CSV header: SourcePortGroup, TargetPortGroup
#>
$NetworkMappingCSV = Import-Csv "VLAN-vCenter01.csv"


<#
	-EnableNetworkMapping : Indicates that the network mapping must be used. Use the SourceNetwork and the TargetNetwork parameters to set the network mapping rules.
	-SourceNetwork : Specifies the array of production networks to which the VMs in the job are connected. Accepts VBRViNetworkInfo type.
	-TargetNetwork : Specifies the array of networks in the DR site. The replicated VMs will be connected to these networks. Accepts VBRViNetworkInfo type.
#>

$NetworkMappingList = @()
ForEach( $Mapping in $NetworkMappingCSV)
{
    $NetworkMapping = "" | Select Source, Target
	$NetworkMapping.Source = Get-vbrserver -name $SourceESXi | Get-VBRViServerNetworkInfo | Where-Object { $_.NetworkName -eq $Mapping.SourcePortGroup }
	$NetworkMapping.Target = Get-vbrserver -name $TargetESXi | Get-VBRViServerNetworkInfo | Where-Object { $_.NetworkName -eq $Mapping.TargetPortGroup }
    $NetworkMappinglist += $NetworkMapping
}

<#
	Import a CSV with VMs that need to be replicated
	CSV contains VMName
#> 
$VMRepList = Get-Content "vmList-vCenter01.txt"

<# 
	Per VM we will create a new replication job.
	To prevent bombing the vCenter and ESXi hosts, each schedule will start a minute after the previous
#>
$10minutes = 0
$minutes = 0

ForEach( $ReplVM in $VMRepList)
{	
	<# 
	Get Source and Target vCenter name in VEEAM Server.
	Note: This is the name you gave the vCenter Server in VEEAM, which could be different from the real vCenter name.
	#>
	$SourcevCenter = Get-VBRServer -Name "vcenter01.source.local"
    $TargetvCenter = Get-VBRServer -Name "vcenter.target.local"

	# Search VM to be replicated in Source vCenter
	$EntSourceObj = @()
	$EntSourceObj = Find-VBRViEntity -Server $SourcevCenter -Name $ReplVM

	# Search VM to be mapped to in Target vCenter
    $EntTargetObj = @()
	$EntTargetObj = Find-VBRViEntity -Server $TargetvCenter -Name $ReplVM
	
	# Step 1: Create the job (name, server, suffix, entity, networkmapping, proxy, restore points)
	# Note: -OriginaVM and -ReplicaVM are VEEAM v9.5 specific !!!
	Add-VBRViReplicaJob -Name "Batch_1_$ReplVM" -Server $TargetESXi -Suffix $Suffix -Entity $EntSourceObj -EnableNetworkMapping -SourceNetwork $NetworkMappingList.Source -TargetNetwork $NetworkMappingList.Target -SourceProxy $ObjSourceProxy -TargetProxy $ObjTargetProxy -RestorePointsToKeep $RestorePoints -OriginalVM $EntSourceObj -ReplicaVM $EntTargetObj
    
	# Step 2: Modify settings of the job (Enable replica seeding + VMMapping)
	$job = Get-VBRJob -Name "Batch_1_$ReplVM" 
	Set-VBRViReplicaJob -Job $job -EnableVMMapping  

	# Step 3: Set and enable the Replication Schedule
	# Start time HOUR then there will be an automatic addition of 1 minute to the start time to prevent bombing the vCenter
	$time = "10:$10minutes$minutes"
	Set-VBRJobSchedule -Job $job -Daily -At $time
	Enable-VBRJobSchedule -Job $job

	#Enable Backup Window
	$ScheduleOptions = Get-VBRJobScheduleOptions -Job $job
	$ScheduleOptions.OptionsBackupWindow.IsEnabled = $true

	# Window allow to run is daily from 10am through 10pm
	$ScheduleOptions.OptionsBackupWindow.BackupWindow = "<scheduler><Sunday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Sunday><Monday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Monday><Tuesday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Tuesday><Wednesday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Wednesday><Thursday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Thursday><Friday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Friday><Saturday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Saturday></scheduler>"
	Set-VBRJobScheduleOptions -job $job -Options $ScheduleOptions
	if ($minutes -lt 9){
    	$minutes += 1
	} else {
    	$minutes = 0
    	$10minutes += 1
	}
   }
