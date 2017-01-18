# Add-PSSnapin VeeamPSSnapin
$VMFailover = read-host "Which VM to failover?"
$VMFound = Get-VBRRestorePoint -Name $VMFailover | Sort-Object $_.creationtime -Descending | Select -First 1
$Continue = Read-host "(YES or NO) Continue with " $vmfound.vmname " Last sync: " $vmfound.CreationTime
If( $Continue = "YES")
{
	Get-VBRRestorePoint -Name $VMFailover | Sort-Object $_.creationtime -Descending | Select -First 1 | Start-VBRViReplicaFailover -Reason "DC Migration" -RunAsync -Planned -Confirm
}
