#region COMMENTS BASED HELP
<#
.Synopsis
    Build SharePoint 2016 Single Server Farm
.DESCRIPTION
    This script will build Web Applications, Service Applications, Site Collections, [...] for a "SP2016 Dev SingleServerFarm".
    ** Please look at the NOTES section for the minimum requirements / assumptions before starting this script. **
.EXAMPLE
    .\DevSPFarm_2016 -DBServerName DCSQL\SP01 -LocalDomain "contoso.com" -AppPoolAcct "SPAppPool" -SPInstallAcct "SPInstall"
.EXAMPLE
    .\DevSPFarm_2016 -DBServerName <SQL Alias> -LocalDomain "contoso.com" -AppPoolAcct spapppool -SPInstallAcct spinstall
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    Assumptions:
        ** SharePoint Server is allowed to "communicate" with SQL Server (firewall rule)
        ** Logged into the SharePoint Server with the "SPInstall" account
.FUNCTIONALITY
    Creates a SP2016 Single Server Farm for Development purposes
#>
#endregion
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the database server name or SQL Alias (e.g. SERVER\INSTANCE)", Position=0)]
    [string]$DBServerName,
    [Parameter(Mandatory = $true, HelpMessage = "Enter your domain name (with .com or .local)", Position=1)]  
    [string]$LocalDomain,
    [Parameter(Mandatory = $true, HelpMessage = "Enter the Application Pool account (e.g. SPAppPool)", Position=2)]
    [string]$AppPoolAcct,
    [Parameter(Mandatory = $true, HelpMessage = "Enter the SPInstall account (e.g. SPInstall)", Position=3)]
    [string]$SPInstallAcct
)
Start-Transcript
#Script started at:
$startTime = "{0:G}" -f (Get-date)
Write-Host "*** Script started on $startTime ***" -ForegroundColor White -BackgroundColor Black

#* Add SharePoint snapin if not running from the SP Mngt Shell
$SPSnapin = Get-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue
if (!$SPSnapin) {
    try {
        Write-Host "SharePoint snapin not present. Trying to add it..." -ForegroundColor Yellow
        Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop
        Write-Host "SharePoint snapin now loaded. Continuing..." -ForegroundColor Green
    }
    catch {
        Write-Error "Unable to load SharePoint snapin."
        break
    }
}
else {
    Write-Host "SharePoint snapin already loaded." -ForegroundColor Green
}

#Split domain 
$SplitDomain = ($LocalDomain).IndexOf(".")
$DomainLeftPart = ($LocalDomain).Substring(0, $SplitDomain)   #e.g.: This is equal to contoso
$DomainRightPart = ($LocalDomain).Substring($SplitDomain+1)  #e.g.: This is equal to .com

#Check if AppPool Account is registered as Managed Acct in SharePoint
$FullAppPoolAcct = Get-SPManagedAccount "$DomainLeftPart\$AppPoolAcct" -ErrorAction SilentlyContinue
if (!$FullAppPoolAcct) {
    try {
        #Register SPAppPool Acct as Managed Acct
        Write-Host "Account not registered. Trying to add it in SharePoint..." -ForegroundColor Yellow  
        $FullAppPoolAcct = "$DomainLeftPart\$AppPoolAcct"
        $AppPoolAcctPwd = Read-Host -Prompt "Please enter the password for $AppPoolAcct" -AsSecureString
        $PassAppPoolCreds = New-Object System.Management.Automation.PSCredential $FullAppPoolAcct, $AppPoolAcctPwd
        New-SPManagedAccount $PassAppPoolCreds -ErrorAction Stop | Out-Null
        Write-Host $FullAppPoolAcct "now registered in SharePoint. Continuing..." -ForegroundColor Green  
    }
    catch {
        Write-Error "Unable to register $AppPoolAcct in SharePoint. Please register the account, and restart the script."
        break
    }
}
else {
    Write-Host $FullAppPoolAcct "registered in SharePoint. Continuing..." -ForegroundColor Green
}

#region CREATE APPLICATION POOLS FOR SAs & FOR WEB APPLICATIONS
#* Create First (and Default) Application Pool for all Service Applications
$ServiceAppsAppPool = New-SPServiceApplicationPool -Name "ServiceAppsAppPool" -Account $FullAppPoolAcct
$SAAppPoolCreated = ($ServiceAppsAppPool).Name

#* Create the Web Applications AppPool (All Web Applications in a single AppPool)
$WebAppsAppPool = New-SPServiceApplicationPool -Name "SharePoint - WebApps" -Account $FullAppPoolAcct
$WAAppPoolCreated = ($WebAppsAppPool).Name
#endregion

Write-Host "*****************************************" -ForegroundColor Cyan
Write-Host "***** Creating Service Applications *****" -ForegroundColor Cyan
Write-Host "*****************************************" -ForegroundColor Cyan


#region CREATE SERVICE APPLICATIONS
#* Create the Business Data Connectivity Service Application (BDC) -- Proxy is created at the same time
$BDCSAName = "Business Data Connectivity Service Application"
$BDCdbName = "SP2016_BDC_DB"
Write-Progress "Creating the BDC Service Application..." -Status "Please wait..."
New-SPBusinessDataCatalogServiceApplication -Name $BDCSAName -ApplicationPool $SAAppPoolCreated -DatabaseServer $DBServerName -DatabaseName $BDCdbName | Out-Null
Write-Host "Business Data Connectivity Service Application created. " -ForegroundColor White


#* Create the Managed Metadata Service Application (MMS) + Proxy
$MMSName = "Managed Metadata Service Application"
$MMSdbName = "SP2016_MMS_DB"
#$MMSAdminAcct = "$DomainLeftPart\$SPInstallAcct"
Write-Progress "Creating the Managed Metadata Service Application..." -Status "Please wait..."

try {
    $MMSSa = New-SPMetadataServiceApplication -Name $MMSName -ApplicationPool $SAAppPoolCreated -DatabaseName $MMSdbName -DatabaseServer $DBServerName -SyndicationErrorReportEnabled -ErrorAction Stop
    New-SPMetadataServiceApplicationProxy -Name "Managed Metadata Service Application Proxy" -ServiceApplication $MMSSa -DefaultProxyGroup -ErrorAction Stop
    Write-Host "Managed Metadata Service Application created. " -ForegroundColor White
    #break
}
catch {
    Write-Error -Message $_.Exception
}


#* Create the State Service Application + Proxy
$StateSAName = "State Service Application"
$StateSAProxyName = "State Service Application Proxy"
$StateSAdbName = "SP2016_State_Service_DB"
Write-Progress "Creating the State Service Application..." -Status "Please wait..."
$StateServiceApp = New-SPStateServiceApplication -Name $StateSAName
$Database = New-SPStateServiceDatabase -Name $StateSAdbName -ServiceApplication $StateServiceApp 
New-SPStateServiceApplicationProxy -Name $StateSAProxyName -ServiceApplication $StateServiceApp -DefaultProxyGroup | Out-Null
Initialize-SPStateServiceDatabase -Identity $Database
Write-Host "State Service Application created. " -ForegroundColor White


#* Create the Usage & Health Data Collection Service Application
Write-Progress "Creating the Usage and Health Data Collection Service Application..." -Status "Please wait..."
New-SPUsageApplication -Name "Usage and Health Data Collection" -DatabaseServer $DBServerName -DatabaseName "SP2016_Usage_And_Health_DB" | Out-Null
$UsageHealthProxy = Get-SPServiceApplicationProxy | Where-Object {$_.TypeName -eq "Usage and Health Data Collection Proxy"}
$UsageHealthProxy.Provision()
Write-Host "Usage & Health Data Collection Service Application created. " -ForegroundColor White


#* User Profile Service Application (UPSA) 
Write-Progress "Creating the User Profile Service Application..." -Status "Please wait..."
New-SPProfileServiceApplication -ApplicationPool $SAAppPoolCreated -Name "User Profile Service Application" -ProfileDBName 'SP2016_User_Profile_DB' -SocialDBName 'SP2016_User_Social_DB' -ProfileSyncDBName 'SP2016_User_Sync_DB' | Out-Null
$UserProfileSA = Get-SPServiceApplication -Name "User Profile Service Application"
New-SPProfileServiceApplicationProxy -ServiceApplication $UserProfileSA -DefaultProxyGroup -Name "User Profile Service Application Proxy" | Out-Null
Write-Host "User Profile Service Application created. " -ForegroundColor White


#* Create the Search Service Application (All components on one server)
$SearchAppPool = $SAAppPoolCreated
$SearchSAName = "Search Service Application"
$searchDBName = "SP2016_Search_Service_DB"
Get-SPServiceApplicationPool $SearchAppPool
Write-Progress "Creating the Search Service Application..." -Status "Please wait... This might take a while." 
Get-SPEnterpriseSearchServiceInstance -Local | Start-SPEnterpriseSearchServiceInstance 
Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Local | Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance 
$SearchSA = New-SPEnterpriseSearchServiceApplication -Name $SearchSAName -ApplicationPool $SearchAppPool -DatabaseName $searchDBName
New-SPEnterpriseSearchServiceApplicationProxy -Name "$SearchSAName Proxy" -SearchApplication $SearchSA
$clone = $SearchSA.ActiveTopology.Clone()
$SearchServInst = Get-SPEnterpriseSearchServiceInstance
New-SPEnterpriseSearchAdminComponent –SearchTopology $clone -SearchServiceInstance $SearchServInst
New-SPEnterpriseSearchContentProcessingComponent –SearchTopology $clone -SearchServiceInstance $SearchServInst
New-SPEnterpriseSearchAnalyticsProcessingComponent –SearchTopology $clone -SearchServiceInstance $SearchServInst 
New-SPEnterpriseSearchCrawlComponent –SearchTopology $clone -SearchServiceInstance $SearchServInst 
New-SPEnterpriseSearchIndexComponent –SearchTopology $clone -SearchServiceInstance $SearchServInst
New-SPEnterpriseSearchQueryProcessingComponent –SearchTopology $clone -SearchServiceInstance $SearchServInst
$clone.Activate()
Write-Host "Search Service Application created. " -ForegroundColor White


#* OPTIONAL --- Create the App Management Service Application + Proxy
$AppMgtName = "App Management Service Application" 
$AppMngtDBName = "SP2016_App_Mngt_DB"
Write-Progress "Creating the App Management Service Application..." -Status "Please wait..."
$AppMgtSA = New-SPAppManagementServiceApplication -Name $AppMgtName -DatabaseServer $DBServerName -DatabaseName $AppMngtDBName -ApplicationPool $SAAppPoolCreated 
New-SPAppManagementServiceApplicationProxy -ServiceApplication $AppMgtSA -Name "$AppMgtName Proxy" 
Write-Host "App Management Service Application created. " -ForegroundColor White


#* OPTIONAL --- Create the Word Automation Service Application  
$WordAutoSA = "Word Automation Service Application"
$WordAutoDBName = "SP2016_Word_Automation_DB"
Write-Progress "Creating the Word Automation Service Application..." -Status "Please wait..."
New-SPWordConversionServiceApplication -Name $WordAutoSA -ApplicationPool $SAAppPoolCreated -DatabaseName $WordAutoDBName -DatabaseServer $DBServerName | Out-Null
Write-Host "Word Automation Service Application created. " -ForegroundColor White


#* OPTIONAL --- Create the Machine Translation Service Application 
$MachineName = "Machine Translation Service Application"
$MachinedbName = "SP2016_Machine_Translation_DB"
Write-Progress "Creating the Machine Translation Service Application..." -Status "Please wait..."
New-SPTranslationServiceApplication -Name $MachineName -DatabaseName $MachinedbName -DatabaseServer $DBServerName -ApplicationPool $SAAppPoolCreated | Out-Null
Write-Host "Machine Translation Service Application created. " -ForegroundColor White

#endregion

Write-Host "*************************************" -ForegroundColor Cyan
Write-Host "***** Creating Web Applications *****" -ForegroundColor Cyan
Write-Host "*************************************" -ForegroundColor Cyan

#region CREATE WEB APPLICATIONS
#* Create the PORTAL Web Application
$PortalAuthProvider = New-SPAuthenticationProvider -UseWindowsIntegratedAuthentication
$WAPortalName = "SharePoint - Portal"
$WAPortalHostHeader = ("portal" + "." + $DomainLeftPart + "." + $DomainRightPart)
$WAPortalUrl = ("http://" + "portal" + "." + $DomainLeftPart + "." + $DomainRightPart)
$WAPortaldbName = "SP2016_Portal_WADB"
Write-Progress "Creating the PORTAL Web Application..." -Status "Please wait..."
New-SPWebApplication -Name $WAPortalName -Port 80 -HostHeader $WAPortalHostHeader -Url "$WAPortalUrl" -ApplicationPool "$WAAppPoolCreated" -ApplicationPoolAccount $FullAppPoolAcct -AuthenticationMethod NTLM -DatabaseServer $DBServerName -DatabaseName $WAPortaldbName -AuthenticationProvider $PortalAuthProvider | Out-Null
Write-Host "PORTAL Web Application created. " -ForegroundColor White


#* Create the SITES Web Application
$SitesAuthProvider = New-SPAuthenticationProvider -UseWindowsIntegratedAuthentication
$WASitesName = "SharePoint - Sites"
$WASitesHostHeader = ("sites" + "." + $DomainLeftPart + "." + $DomainRightPart)
$WASitesUrl = ("http://" + "sites" + "." + $DomainLeftPart + "." + $DomainRightPart)
$WASitesdbName = "SP2016_Sites_WADB"
Write-Progress "Creating the SITES Web Application..." -Status "Please wait..."
New-SPWebApplication -Name $WASitesName -Port 80 -Url "$WASitesUrl" -HostHeader $WASitesHostHeader -ApplicationPool "$WAAppPoolCreated" -AuthenticationMethod NTLM -DatabaseServer $DBServerName -DatabaseName $WASitesdbName -AuthenticationProvider $SitesAuthProvider | Out-Null
Write-Host "SITES Web Application created. " -ForegroundColor White


#* Create the SEARCH Web Application 
$SearchWAAuthProvider = New-SPAuthenticationProvider -UseWindowsIntegratedAuthentication
$WASearchName = "SharePoint - Enterprise Search"
$WASearchHostHeader = ("search" + "." + $DomainLeftPart + "." + $DomainRightPart)
$WASearchUrl = ("http://" + "search" + "." + $DomainLeftPart + "." + $DomainRightPart)
$WASearchdbName = "SP2016_Search_WADB"
Write-Progress "Creating the SEARCH Web Application..." -Status "Please wait..."
New-SPWebApplication -Name $WASearchName -Port 80 -Url "$WASearchUrl" -HostHeader $WASearchHostHeader -ApplicationPool "$WAAppPoolCreated" -AuthenticationMethod NTLM -DatabaseServer $DBServerName -DatabaseName $WASearchdbName -AuthenticationProvider $SearchWAAuthProvider | Out-Null
Write-Host "SEARCH Web Application created. " -ForegroundColor White

#endregion

Write-Host "*************************************" -ForegroundColor Cyan
Write-Host "***** Creating Site Collections *****" -ForegroundColor Cyan
Write-Host "*************************************" -ForegroundColor Cyan


#region CREATE SITE COLLECTIONS
#* Create the PORTAL ROOT site collection
$PortalSCName = "Portal"
$PortalSCOwner = $SPInstallAcct
$PortalSCTemplate = "STS#0"
Write-Progress "Creation of the Portal Site Collection..." -Status "Please wait..."
New-SPSite -Url "http://portal.$DomainLeftPart.$DomainRightPart/" -Template $PortalSCTemplate -Name $PortalSCName -Description "Site Collection for the Portal" -OwnerAlias $PortalSCOwner -ContentDatabase $WAPortaldbName -Language "1033" | Out-Null
Write-Host "PORTAL Site Collection created. " -ForegroundColor White


#* Create the SITES ROOT site collection
$SitesSCName = "Sites for Collaboration"
$SitesSCOwner = $SPInstallAcct
$SitesSCTemplate = "STS#0"
Write-Progress "Creation of the Sites Site Collection..." -Status "Please wait..."
New-SPSite -Url "http://sites.$DomainLeftPart.$DomainRightPart/" -Template $SitesSCTemplate -Name $SitesSCName -Description "Site Collection for the Sites Web Application" -OwnerAlias $SitesSCOwner -ContentDatabase $WASitesdbName -Language "1033" | Out-Null
Write-Host "SITES Site Collection created. " -ForegroundColor White


#* Create the SEARCH ROOT site collection (using the Search Center template)
$SearchSCName = "Enterprise Search Center"
$SearchSCOwner = $SPInstallAcct
$SearchSCTemplate = "SRCHCEN#0"
Write-Progress "Creation of the Enterprise Search Site Collection..." -Status "Please wait..."
New-SPSite -Url "http://search.$DomainLeftPart.$DomainRightPart/" -Template $SearchSCTemplate -Name $SearchSCName -Description "Site Collection for the Search Center" -OwnerAlias $SearchSCOwner -ContentDatabase $WASearchdbName -Language "1033" | Out-Null
Write-Host "ENTERPRISE SEARCH CENTER Site Collection created. " -ForegroundColor White
#endregion

#Script ended at:
$endTime = "{0:G}" -f (Get-date)
Write-Host "*** Script finished on $endTime ***" -ForegroundColor White -BackgroundColor Black
Write-Host "Time elapsed: $(New-Timespan $startTime $endTime)" -ForegroundColor White -BackgroundColor DarkRed

Stop-Transcript