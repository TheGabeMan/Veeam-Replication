# Snapin nodig? 
# Add-PSSnapin VeeamPSSnapin


$VMFailover = read-host "Welke VM overfailen?"
$VMFound = Get-VBRRestorePoint -Name $VMFailover | Sort-Object $_.creationtime -Descending | Select -First 1
$Continue = Read-host "(YES/NO) Continue with " $vmfound.vmname " Last sync: " $vmfound.CreationTime
If( $Continue = "YES")
{
	Get-VBRRestorePoint -Name $VMFailover | Sort-Object $_.creationtime -Descending | Select -First 1 | Start-VBRViReplicaFailover -Reason "Batch 2 (14jan)" -RunAsync -Planned -Confirm
}
