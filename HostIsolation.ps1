#Set path to export enabled firewall rules to
$path = "$Env:temp\firewall.csv"
$debug = "$Env:temp\firewall-debug.log"

#Path to the Control/ScreenConnect client
$controlpath = "C:\Program Files (x86)\ScreenConnect Client"

#Path to the LabTech/Automate client
$ltpath = "C:\Windows\LTSvc"

#See if product is Wokstation (1) Domain Controller (2) Server (3) - we probably want to exit if domain controller/servers as to not nuke org authentication or higher level functionality
function Get-OSFunction
{
    $ostype = ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType)
    if ($ostype -eq 1) {
        Write-Output "Workstation"
        Write-Output $ostype
    }elseif ($ostype -eq 2) {
        Write-Output "Domain Controller - Exiting"
        exit
        Write-Output "After Exit"
        Write-Output $ostype
    }elseif ($ostype -eq 3) {
        Write-Output "Regular Server - Exiting"
        exit
        Write-Output $ostype
    }
}

##Export all enabled firewall rules to CSV defined by $path 
function Export-EnabledFWRules
{
    Get-NetFirewallRule | Where { $_.Enabled –eq 'True'} | Select-Object -Property Name,DisplayName,Enabled,Profile,Direction | Export-CSV -Path $path -Force -NoTypeInformation
}

#Testing function for viewing the rules that were saved in notepad
function View-SavedFWRules
{
    notepad $path
}

#Testing function for listing the rules that were saved in console
function List-SavedFWRules
{
    Import-Csv $path | Foreach-Object { 
        Write-Host $_.Name
	Write-Host $_.DisplayName
    } 
}

#Disable all firewall rules listed in the exported file
#We are using exported file and not realtime enumeration to ensure the export was successful in the event the rules need to be reenabled
function Disable-AllFWRules
{
    Import-Csv $path | Foreach-Object { 
        Disable-NetFirewallRule -Name "$_.Name" | Out-File -FilePath $debug -Append
    } 
}

function Enable-AllFWRules
{
    Import-Csv $path | Foreach-Object { 
        Enable-NetFirewallRule -Name "$_.Name" | Out-File -FilePath $debug -Append
    } 
}

#Disable ALL inbound/outbound communication that doesn't match a FW Rule
function Disable-AllCommunication
{
    Set-NetFirewallProfile -Name Domain -DefaultOutboundAction Block -DefaultInboundAction Block
    Set-NetFirewallProfile -Name Private -DefaultOutboundAction Block -DefaultInboundAction Block
    Set-NetFirewallProfile -Name Public -DefaultOutboundAction Block -DefaultInboundAction Block
}

#Allow outbound communication that doesn't match a FW Rule - we don't do this on inbound, that defeats the purpose of a firewall
function Enable-AllCommunication
{
    Set-NetFirewallProfile -Name Domain -DefaultOutboundAction Enable -DefaultInboundAction Block
    Set-NetFirewallProfile -Name Private -DefaultOutboundAction Enable -DefaultInboundAction Block
    Set-NetFirewallProfile -Name Public -DefaultOutboundAction Enable -DefaultInboundAction Block
}

###enable DNS outbound to ensure we can resolve service names for remote management while the host is isolated
function Enable-DNSOut
{
    Enable-NetFirewallRule -DisplayName "Core Networking - DNS (UDP-Out)"
}

###enable inbound RDP
function Enable-RDPInbound
{
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

###enable ConnectWise Control/ScreenConnect connectivity -  ensure $controlpath at top of script is updated to match the install path
function Add-ScreenConnectFWRules
{
    New-NetFirewallRule -DisplayName "Allow ScreenConnect Client Service" -Direction Inbound -Program "$controlpath\ScreenConnect.ClientService.exe" -RemoteAddress Any -Action Allow
    New-NetFirewallRule -DisplayName "Allow ScreenConnect Windows Client" -Direction Inbound -Program "$controlpath\ScreenConnect.WindowsClient.exe" -RemoteAddress Any -Action Allow
    New-NetFirewallRule -DisplayName "Allow ScreenConnect Client Service" -Direction Outbound -Program "$controlpath\ScreenConnect.ClientService.exe" -RemoteAddress Any -Action Allow
    New-NetFirewallRule -DisplayName "Allow ScreenConnect Windows Client" -Direction Outbound -Program "$controlpath\ScreenConnect.WindowsClient.exe" -RemoteAddress Any -Action Allow
}

###enable ConnectWise Automate/LabTech connectivity, ensure $ltpath at top of script is updated to match the install path
function Add-LabTechFWRules
{
    New-NetFirewallRule -DisplayName "Allow LabTech Client Service" -Direction Inbound -Program "$ltpath\LTSVC.exe" -RemoteAddress Any -Action Allow
    New-NetFirewallRule -DisplayName "Allow LabTech Tray Client" -Direction Inbound -Program "$ltpath\LTTray.exe" -RemoteAddress Any -Action Allow
    New-NetFirewallRule -DisplayName "Allow LabTech Client Service" -Direction Outbound -Program "$ltpath\LTSVC.exe" -RemoteAddress Any -Action Allow
    New-NetFirewallRule -DisplayName "Allow LabTech Tray Client" -Direction Outbound -Program "$ltpath\LTTray.exe" -RemoteAddress Any -Action Allow
}



##################################################################################################
###Start execution of isolation functions
###Please comment out the lines you don't want to execute
###You must uncomment Disable-AllFWRules AND Disable-AllCommunication for actual host isolation
###Order of operation matters

###We see what type of box this is - by default we exit on servers and domain controllers
###as to not accidentially nuke the world
Get-OSFunction

###First export the firewall rules that are currently enabled
Export-EnabledFWRules

###Disable all enabled firewall rules (must uncomment to ensure execution)
###Disable-AllFWRules

###Disable ALL inbound/outbound communication that doesn't match a FW Rule 
###(must uncomment to ensure execution)
###Disable-AllCommunication

###Enable RDP Inbound for remote desktop access - this can be a security risk depending on 
###the posture of the machine
###Enable-RDPInbound

###Enable outbound DNS rules - this ensures dependent services that may need to communicate
###with the DNS names of a service can (think Control/Automate/etc)
Enable-DNSOut

###Add firewall rules for ScreenConnect/Control connectivity (may be dependent on outbound DNS)
Add-ScreenConnectFWRules

###Add firewall rules for LabTech/Automate connectivity (may be dependent on outbound DNS)
Add-LabTechFWRules
##################################################################################################


##################################################################################################
###These functions reverse host isolation
###This function will reenable all previously disabled firewall rules from the $path location
###Enable-AllFWRules

###This function will reenable outbound communication
###Enable-AllCommunication
###################################################################################################
