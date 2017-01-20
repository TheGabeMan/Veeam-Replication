# Veeam-Replication
Creating VEEAM Replication jobs with PowerShell for Datacenter Migrations
http://gabesvirtualworld.com/datacenter-migration-veeam-backup-replication-powershell/

For new customers we often need to migrate their virtual machines from their datacenter into our datacenter. We use VEEAM Backup & Replication for this because it offers us the ability to pre-sync the VMs a few days before the migration and on the day of the migration it self, the last data sync is very short and therefore the downtime for the customer is often reduced to less then one hour. With big migrations of many VMs, it is sometimes a hassle to create all the replication jobs, especially if you keep in mind that there is one important note in the VEEAM documentation that says:

"Limitations for Planned Failover. If you start planned failover for several VMs that are replicated with one replication job, these VMs will be processed one by one, not in parallel. Each planned failover task for each VM is processed as a separate replica job session. If a backup proxy is not available and the session has to wait for resources, job sessions for other VMs in the same task cannot be started before the current session is finished."

Because of this, I wanted to create a replication job per VM. This gives me the freedom to kick off the failover of multiple VMs for application batches as the customer defines them and make full use of all infrastructure resources (proxies, network bandwith) that are available.

CreateReplicationJobs

Together with my colleagues Annelies Maex and Joren De Spaey, I wrote the CreateReplicationJobs scripts to help in the preparations of the migration and a simple script to kick off the failover per VM. The CreateReplicationJobs.ps1 script needs two CSV files as input. The first one is the VLAN mapping or PortGroup mapping. The source VM is connected to a certain portgroup on the source site and in most cases it should be switched to a new portgroup when powered on at the target site. VLAN-vCenter01.csv contains a source to target mapping of these portgroups. The second file is the simple vmList-vCenter01.txt that contains all the VMs that should be migrated and will thus get a replication job.

Since VEEAM can use seeding of VMs, we usually have old VM backups transfered to our datacenter long before the migration, to limit the amount of data that needs to be synced. Therefore, this script assumes there is a replica VM on the target site that can be mapped to. We've also added an one minute time difference between each job, to prevent VEEAM from 'blowing up' your vCenter with too many tasks at once, although VEEAM usually handles this already very nicely.

Sync in 30 minutes

To give you an idea of how fast we're running the jobs, I created two VEEAM proxies of each 8 vCPU on the source site and two on the target site and we could kick off and finish 70 sync jobs in 30minutes. Even though only a limited amount of data needed to be synced, the handling of the whole process per VM very much benefits from having many vCPUs in the proxies. The scan of the infrastructure, create snapshot, commit snapshot, apply delta's etc, is often more time consuming then the datatransfer itself.

Please find the scripts on GitHub https://github.com/TheGabeMan/Veeam-Replication and follow the master branch, as I'm planning to add more stuff in the weeks to come.

A big thanks to Annelies Maex and Joren De Spaey for their help.
