# script automates ova deployment for VMWare
#
# .\deploy_ova.ps1 [image_version_nr] [ova_name] [nr_of_vms] [template_name]
#     ex.: .\deploy_ova_vmw.ps1 2.6.0 "ova_test" 1  ""
#
#  ======================================================================================================================


function info {
    param($v, $n, $nr, $t)

    write-host "Running deploy_ova.ps1 with parameters: `n version: $v, `n ova_name: $n, `n nr_of_vms $nr, `n template_name $t"
}

function help {
    write-host "deploy script for IPM ova images"
    write-host "  .\deploy_ova.ps1 [image_version_nr] [ova_name] [nr_of_vms] [template_name]"
    write-host "      ex.: .\deploy_ova_vmw.ps1 2.6.0 ova_test 1  `"`""
}

# TODO: not implemented yet 
function connect_to_vsphere {
    write-host "Connecting to vc-ova...."
    Connect-VIServer -Server "vc-ova.roz.lab.etn.com" -Force -UserName '' -Password ''

    $vmCluster = Get-Cluster
    $vmHost = ($vmCluster | Get-VMHost)[0]
    $vmDatastore = Get-Datastore -Name ova-storage-nas13

    write-host "Cluster:  $($vmCluster)"
    write-host "VM Host:  $($vmHost)"
    write-host "Using storage: $($vmDatastore)"
}


#  ======================================================================================================================

# check nr. of input arguments
if ($args.Count -ne 4) {
    help
    
    Exit 1
}

$VERSION = $args[0]
$TOMCAT = "http://tomcat.mbt.lab.etn.com:8088/images/IPM2/release/$($VERSION)/Debian_11/x86_64/deploy-ova/"
$LIST = wget $($TOMCAT)
$DOWN_PATH = "c:\Users\$($env:username)\"
$TEMPLATE = $args[3] 
$IMG_NAME = $($LIST).links | Select-String -InputObject {$_.innerHTML} -Pattern "\.ova$" | Select-Object -Last 1

info -v $args[0] -n $args[1] -nr $args[2] -t $args[3] 

if (!$TEMPLATE) {
    # I am not using template - download .ova image 
    New-Item -Path $DOWN_PATH  -Name "ova_deploy" -ItemType "directory"  -Force > $null
    write-host "Downloading IPM image: $($IMG_NAME) to $($DOWN_PATH)ova_deploy\"

    Invoke-WebRequest -Uri "$($TOMCAT)\$($IMG_NAME)" -OutFile "$($DOWN_PATH)\ova_deploy\$($IMG_NAME)"   
} 

write-host "Connecting to vc-ova...."
Connect-VIServer -Server "vc-ova.roz.lab.etn.com" -Force -UserName '' -Password ''

$vmCluster = Get-Cluster
$vmHost = ($vmCluster | Get-VMHost)[0]
$vmDatastore = Get-Datastore -Name ova-storage-nas13

write-host "Cluster:  $($vmCluster)"
write-host "VM Host:  $($vmHost)"
write-host "Using storage: $($vmDatastore)"

if ($env:username -eq "E9955296") {
   $init = "BK"
}
else {
   $init = "RK"
}

for ($i = 1; $i -le $args[2]; $i++) {
    $vmName = "$($args[1])_$($init)_0$($i)"
    
    if (!$TEMPLATE) {
        write-host "`nImporting OVA package with name: $($vmName)"
        $vmSource = "$($DOWN_PATH)\ova_deploy\$($IMG_NAME)"	
        $vmHost | Import-vApp -Source $vmSource -Location $vmCluster -Datastore $vmDatastore -Name $vmName

    } 
    else {
        write-host "`nCreating new VM from template $($Template)"
        New-VM -Name $vmName -Template $TEMPLATE -VMHost $vmHost	

    }

    # VM Network Settings
    $38Network = "38-Network"
    $54Network = "54-Network"

    # Change the VM network and start the VM
    get-vm $vmName | Get-NetworkAdapter | where{$_.networkname -match "38-network"} | Set-NetworkAdapter -NetworkName $54Network -Confirm:$false

    Set-Network-Adapter
    write-host "Starting VM $($vmName)"
    Start-VM $vmName 

    do {
    	# Wait for the vmware tools to start
	Start-Sleep -s 10
	write-host "Waiting for VM Tools to Start..."
	$toolsStatus = (Get-VM $vmName | Get-View).Guest.ToolsStatus
        write-host $toolsStatus
    } until ($toolsStatus -eq 'toolsOk')

    # Get IP address of the VM
    Start-Sleep -s 30
    write-host "Here comes your IP:"
    Get-VM -Name $vmName | Select-Object Name, @{N="IP";E={@($_.Guest.IPAddress)}}

} 

Exit 0 
