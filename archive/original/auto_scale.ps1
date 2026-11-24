# ==============================================
# NEXTCLOUD AUTO-SCALING & HEALTH CHECK SIMULATION
# ==============================================

# Containers to monitor
$containers = @("nextcloud-app", "nextcloud-app-2")

# Infinite monitoring loop
while ($true) {
    Clear-Host
    Write-Host ("Checking container health... " + (Get-Date))
    
    foreach ($c in $containers) {
        $status = docker inspect -f '{{.State.Running}}' $c 2>$null

        if ($status -eq "true") {
            Write-Host "$c is healthy and running."
        } else {
            Write-Host "$c is down! Restarting instance..."
            $newName = "$c-replica-" + (Get-Random -Minimum 100 -Maximum 999)

            # Launch replacement container
            docker run -d --name $newName --network cctemp_default nextcloud:29 | Out-Null
            Write-Host "New instance launched: $newName"
        }
    }

    Write-Host "Waiting 20 seconds before next health check..."
    Start-Sleep -Seconds 20
}

