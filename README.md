# Dev-SPFarm-2016

## Summary

Create Service Applications, Web Applications, and Site Collections for a **_development single server_** SharePoint 2016 farm.

## Assumptions

* SharePoint Server 2016 is installed, and Central Administration website is accessible.
* No other databases are present except the _SP Admin Content_ database & the _SP Config_ database.
* SharePoint Server is allowed to **"_communicate_"** with the database server (_firewall rule_)
* Logged into the SharePoint Server 2016 with the **"_SPInstall_"** account
* Application Pool account is already created (_if not added in SharePoint as a managed account, the script will try to add it for you._)


# What will the script create?

## Service Applications

The following _Service Applications_ (_SA_) will be created:

* Business Data Connectivity
* Managed Metadata 
* State Service 
* Usage & Health Data Collection
* User Profile (_UPSA_)
* Search (_all components on one server_)
* App Management
* Word Automation
* Machine Translation

Each Service Application can be commented out in the script if not needed (_e.g.: Word Automation_).

## Web Applications

The following _Web Applications_ will be created:

* Portal
* Sites
* Search

## Site Collections

The following _Site Collections_ will be created:

* Portal (_Team Site template under the Portal Web Application_)
* Sites (_Team Site template under the Sites Web Application_)
* Enterprise Search  (_Enterprise Search Center template under the Search Web Application_)

# Run the script

* The script should be run on the SharePoint 2016 Server.
* The script can be run from the _SharePoint Management Shell_, or from the _regular PowerShell console_ (Get-PSSnapin will be checked).
* The ``` -DBServerName ``` parameter uses _<Server\Instance>_ or can be _SQLAlias_

**Running the script:**

.\DevSPFarm_2016 -DBServerName _<Server\Instance>_ -LocalDomain "_<myDomain.com>_" -AppPoolAcct _<SPAppPool_Acct>_ -SPInstallAcct _<SPInstall_Acct>_


Examples:

``` .\DevSPFarm_2016 -DBServerName DCSQL\SP01 -LocalDomain "contoso.com" -AppPoolAcct SPAppPool -SPInstallAcct SPInstall ```

or

``` .\DevSPFarm_2016 -DBServerName DCSQL02 -LocalDomain "contoso.net" -AppPoolAcct spapppool -SPInstallAcct spinstall ```


# Artifacts

The following artifacts are integrated in the script:

* Check if the ``` Microsoft.SharePoint.PowerShell ``` snapin is present
* Check if the _Application Pool account_ is registered in SharePoint as managed account
* Will log a transcript (_using_ ``` Start-Transcript ``` _and_ ``` Stop-Transcript ```)
* Progress bar at the top to know what's happening
* Will display at the end, how long the script took to run


# Screenshots

Please have a look at the _Screenshots_ folder.


# Disclaimer

**SCRIPT IS PROVIDED _AS-IS_ WITHOUT WARRANTY OF ANY KIND, AND IS MEANT FOR DEVELOPMENT / TESTING PURPOSES.**
