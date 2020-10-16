Deploying SQL Maintenance Scripts
=================================

This contains what is needed to deploy SQL scripts across multiple environments. This is a simple process that uses a PowerShell script and a JSON config file. 

- PowerShell script - Deploy-Scripts.ps1 - which accepts a single parameter (DeploySecure) 

- JSON config file - Config.json - this contains the directory where the scripts will be placed before deployment, as well as a list of the servers and type or classification of the server (i.e. zone1_servers, zone2_servers, etc.)

The parameter `DeploySecure` in the PowerShell script lets you run the scripts on separate firewalled servers. I have two separate firewall zones that I deploy to, so this allows me to easily distinguish between the servers getting updates.


### How to use the scripts

1. Download the repository to your local machine
2. Prepare the SQL scripts as outlined above and place them in the `ScriptDirectory` for deployment. This might be just one script that is changing or multiple.
3. Verify that no changes need to made to the list of servers or other configurations in the .json file
4. Open a PowerShell window and browse to the repository
5. Run `.\Deploy-Scripts.ps1 -DeploySecure $false` for zone 1 servers and then `.\Deploy-MaintenanceScripts.ps1 -DeploySecure $true` for zone 2 servers