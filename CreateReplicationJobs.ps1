# Reading a CSV with VMs that needs to be replicated
# List contains VMNaam, vCenterNaam (vCenter as described in VEEAM)
# Authors: Annelies Maex & Gabrie van Zanten & Joren De Spaey
# linkedin: https://be.linkedin.com/in/anneliesmaex
# linkedin: https://www.linkedin.com/in/jorendespaey

#Add-PSSnapin VeeamPSSnapin
# $VMRepList = Get-Content "vmList-vCenter01.txt"
# $VMRepList = Get-Content "vmList-vCenter02.txt"
$VMRepList = Get-Content "vmList-vCenter03.txt"

# Replication Job settings:
# https://helpcenter.veeam.com/docs/backup/powershell/add-vbrvireplicajob.html?ver=95
# Name: Specifies the name you want to assign to the replication job.
# Server: Specifies the target VMware host where the created replica will be stored.
# Entity: Specifies the array of  VMs you want to add to this job.


# Suffix: Specifies the suffix that will be appended to the name of the VM you are replicating. This name will be used to register the replicated VM on the target server. Default: "_replica".
# We want suffix to be empty to prevent being stuck with _replica after the migration
$Suffix = " "

# Enable Network Mapping. Indicates that the network mapping must be used. Use the SourceNetwork and the TargetNetwork parameters to set the network mapping rules.
# Source Network: For network mapping. Specifies the array of production networks to which the VMs in the job are connected. Accepts VBRViNetworkInfo type.
# Target Network: For network mapping. Specifies the array of networks in the DR site. The replicated VMs will be connected to these networks. Accepts VBRViNetworkInfo type.
# Networks should be read from an ESXi host NOT through vCenter !!!
# A CSV is used to import a list of mappings. The CSV is made up of the following fields:
# Source PortGroup = SourcePortGroup
# Target PortGroup = TargetPortGroup

# Source ESXi host = SourceESXi
# Source ESXi voor vCenter1
# $SourceESXi = "esxhtw05a.opg.local"

# Source ESXi voor vCenter2
# $SourceESXi = "esxtys028.opg.local" 

# Source ESXi voor vCenter3
$SourceESXi = "esxhtw021.opg.local"

# Target ESXi host = TargetESXi
$TargetESXi = "mdqvm001.mdq-openline.local"

# $NetworkMappingCSV = Import-Csv "VLAN-vCenter01.csv"
# $NetworkMappingCSV = Import-Csv "VLAN-vCenter02.csv"
$NetworkMappingCSV = Import-Csv "VLAN-vCenter03.csv"

$NetworkMappingList = @()

ForEach( $Mapping in $NetworkMappingCSV)
{
    $NetworkMapping = "" | Select Source, Target
	$NetworkMapping.Source = Get-vbrserver -name $SourceESXi | Get-VBRViServerNetworkInfo | Where-Object { $_.NetworkName -eq $Mapping.SourcePortGroup }
	$NetworkMapping.Target = Get-vbrserver -name $TargetESXi | Get-VBRViServerNetworkInfo | Where-Object { $_.NetworkName -eq $Mapping.TargetPortGroup }
    $NetworkMappinglist += $NetworkMapping
}

# Source Proxy: Specifies the source proxy you want to assign to the job. Default: automatic selection.
# Target Proxy: Specifies the target proxy you want to assign to the job. Default: automatic selection.
# Retreive proxies using: get-vbrviproxy -name "veeamproxy1"

$ObjSourceProxy = @()
$ObjSourceProxy += Get-VBRViProxy -name "veeamproxy1"
$ObjSourceProxy += Get-VBRViProxy -name "veeamproxy2"

$ObjTargetProxy = @()
$ObjTargetProxy += Get-VBRViProxy -name "MDQPR003"
$ObjTargetProxy += Get-VBRViProxy -name "MDQPR004"

# Restore Points ToKeep: Specifies the number of restore points you want to keep. Permitted values: 1 to 28. Default: 7.
$RestorePoints = 1

# OriginalVM: For replica mapping. Specifies the production VM you want to replicate using replica mapping. The replication job will map this VM to a selected replica VM on the DR site. Use the ReplicaVM parameter to specify the replica VM on the DR site.
# ReplicaVM: For replica mapping. Specifies the VM on the DR site you want to use as the replication target. The replication job will map the production VM to this VM. Use the OriginalVM parameter to specify the production VM. 


# Per VM we will create a new replication job
$10minutes = 0
$minutes = 0

ForEach( $ReplVM in $VMRepList)
{	
	# Get Source vCenter name in VEEAM Server
	$SourcevCenter = Get-VBRServer -Name "vcentglp01.opg.local"
    # $SourcevCenter = Get-VBRServer -Name "vcentglp02.opg.local"
    $TargetvCenter = Get-VBRServer -Name "MDQVC001"

	# Search VM to be replicated in Source vCenter
	$EntSourceObj = @()
	$EntSourceObj = Find-VBRViEntity -Server $SourcevCenter -Name $ReplVM

    $EntTargetObj = @()
	$EntTargetObj = Find-VBRViEntity -Server $TargetvCenter -Name $ReplVM
	
	# Step 1: Create the job (name, server, suffix, entity, networkmapping, proxy, restore points)
    # Read-Host $ReplVM 
	Add-VBRViReplicaJob -Name "Batch_3_vcentglp01_$ReplVM" -Server $TargetESXi -Suffix $Suffix -Entity $EntSourceObj -EnableNetworkMapping -SourceNetwork $NetworkMappingList.Source -TargetNetwork $NetworkMappingList.Target -SourceProxy $ObjSourceProxy -TargetProxy $ObjTargetProxy -RestorePointsToKeep $RestorePoints -OriginalVM $EntSourceObj -ReplicaVM $EntTargetObj
    
    # Step 2: Modify settings of the job (Enable replica seeding + VMMapping)
    $job = Get-VBRJob -Name "Batch_3_vcentglp01_$ReplVM" 
    Set-VBRViReplicaJob -Job $job -EnableVMMapping  

    # Set and enable the Replication Schedule
    # Start time HOUR then there will be an automatic addition of 1 minute to the start time to prevent bombing the vCenter
    $time = "10:$10minutes$minutes"
    Set-VBRJobSchedule -Job $job -Daily -At $time
    Enable-VBRJobSchedule -Job $job

    #Enable Backup Window
    $ScheduleOptions = Get-VBRJobScheduleOptions -Job $job
    $ScheduleOptions.OptionsBackupWindow.IsEnabled = $true
    $ScheduleOptions.OptionsBackupWindow.BackupWindow = "<scheduler><Sunday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Sunday><Monday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Monday><Tuesday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Tuesday><Wednesday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Wednesday><Thursday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Thursday><Friday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Friday><Saturday>1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1</Saturday></scheduler>"
    Set-VBRJobScheduleOptions -job $job -Options $ScheduleOptions
    if ($minutes -lt 9){
        $minutes += 1
    } else {
        $minutes = 0
        $10minutes += 1
    }
}
