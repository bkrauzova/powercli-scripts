# script deletes specified vms
#
# ./delete_vms.ps1 [vm1] [vm2] [...]
#     ex.: ./delete.ps1 vm1 vm2 vm3
#
# ===================================================================================

function connect {
    write-host "Connecting to vc-ova...."
    Connect-VIServer -Server "vc-ova.roz.lab.etn.com" -Force -UserName '' -Password ''
}

# ===================================================================================

connect

$i = 1
while (args[$i]) {
    wtite-host "Pernamently deleting VM: $($args[$($i)])"
    Remove-VM -VM $args[$i] -DeletePernamently $true
    Start-Sleep -s 1
          
}

