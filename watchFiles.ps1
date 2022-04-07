# Based on: https://powershell.one/tricks/filesystem/filesystemwatcher
# Call with default parameters: .\watchFiles.ps1
# Specify a diretory to watch: .\watchFiles.ps1 -WatchPath "..\path\to\dir\"
# Specify a command to pass the file to: .\watchFiles.ps1 -WatchPath "..\path\to\dir\" -Command programToRun
param(
    $WatchPath=".\"         # Path of directory to watch
    ,$Command="powershell"  # Command/program to pass the file to
)

Clear-Host
try
{
    # Directory to watch
    $WatchPath = (Get-Item $WatchPath).FullName
    $fileFilter = "*.*"     # Pattern for files to watch for
    $includeSubDirs = $true # Watch subdirectories as well

    # Properties of files to watch
    $properties = @([IO.NotifyFilters]::FileName
        ,[IO.NotifyFilters]::LastWrite `
    )
    $timeout = 0.2          # Poll for any event fired every 200 milliseconds

    # Create the FileSystemWatcher object
    $watcher = New-Object -TypeName IO.FileSystemWatcher -ArgumentList $WatchPath, $fileFilter `
        -Property @{IncludeSubdirectories = $includeSubDirs;
            NotifyFilter = $properties}

    # Register event handlers
    $handlers = . {
        Register-ObjectEvent -InputObject $watcher -EventName Changed
        Register-ObjectEvent -InputObject $watcher -EventName Created
        Register-ObjectEvent -InputObject $watcher -EventName Deleted
        Register-ObjectEvent -InputObject $watcher -EventName Renamed
    }

    # Start monitoring
    Write-Host "Now monitoring $WatchPath"
    $watcher.EnableRaisingEvents = $true

    # Create a dictionary whose keys are filenames that have been created/deleted/modified
    $filenames = @{}
    do
    {
        $waitevent = Wait-Event -Timeout $timeout
        if($null -ne $waitevent)
        {
            # Wait for all events to fire after one event has fired
            # Write-Host "Sleeping"
            # Start-Sleep -Seconds $timeout
            # Write-Host "Up"
            $events = Get-Event

            # Loop through all events and get filenames
            for($n = 0; $n -lt $events.Length; $n++)
            {
                $filenames[$events[$n].SourceEventArgs.Name] = ""
                Remove-Event -EventIdentifier $events[$n].EventIdentifier
            }

        }
        else
        {
            # Loop through all filenames
            $N = $filenames.Count
            if($N -gt 0)
            {
                foreach($key in $filenames.keys)
                {
                    Clear-Host

                    # Execute some code to do something with the filenames
                    Write-Host "$((Get-Date).ToString("yyyy-MM-dd hh:mm:ss:fff")) $key changed"

                    # NOTE: Write additional commands here
                    Write-Host "$Command $WatchPath$key"
                    Invoke-Expression "$Command $WatchPath$key"
                }
            }
            
            # Clear the hashtable for when the next set of events fire
            $filenames.clear()
        }
    } while ($true)
}
finally
{
    # stop monitoring
    $watcher.EnableRaisingEvents = $false

    # remove the event handlers
    $handlers | ForEach-Object {
        Unregister-Event -SourceIdentifier $_.Name
    }

    # event handlers are technically implemented as a special kind
    # of background job, so remove the jobs now:
    $handlers | Remove-Job

    # properly dispose the FileSystemWatcher:
    $watcher.Dispose()
}
