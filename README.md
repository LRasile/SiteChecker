# SiteChecker

A PowerShell CLI tool that checks whether a list of websites are up or down. Designed to run daily via Windows Task Scheduler and alert you when something is broken.

## Requirements

- Windows with PowerShell 5.1 or later (built into Windows 10/11)

## Setup

1. Clone or download this repo
2. Edit `sites.txt` and add the URLs you want to monitor

## sites.txt

Add one URL per line. Lines starting with `#` are treated as comments and ignored.

```
# Production
https://yoursite.com
https://api.yourservice.com/health

# Staging
https://staging.yoursite.com
```

## Running Manually

Open a terminal in the project folder and run:

```powershell
.\SiteChecker.ps1
```

Optional parameters:

```powershell
# Use a different sites file
.\SiteChecker.ps1 -SitesFile "C:\path\to\my-sites.txt"

# Change the timeout (default is 10 seconds)
.\SiteChecker.ps1 -TimeoutSec 15

# Combine parameters
.\SiteChecker.ps1 -SitesFile "C:\my-sites.txt" -TimeoutSec 20 -LogDir "C:\Logs\SiteChecker"
```

Each run saves a timestamped log file to the `logs\` folder (auto-created on first run).

## Scheduling with Windows Task Scheduler

1. Open **Task Scheduler** (search for it in the Start menu)
2. Click **Create Basic Task** in the right panel
3. Give it a name (e.g. `SiteChecker`) and click **Next**
4. Set your trigger — choose **Daily** and pick a time, then click **Next**
5. For the action, select **Start a program** and click **Next**
6. Fill in the fields:
   - **Program/script:** `powershell.exe`
   - **Add arguments:** `-ExecutionPolicy Bypass -File "Z:\Code\SiteChecker\SiteChecker.ps1"`
   - **Start in:** `Z:\Code\SiteChecker`
7. Click **Finish**

### Tip: Alert on failure

The script exits with code `1` if any sites are down and `0` if all are up. You can use this in Task Scheduler to trigger an action on failure:

1. Open the task you created, go to the **Conditions** or **Settings** tab
2. Or add a second action that runs only when the first action fails — point it to a script that sends you a notification, email, or writes to a separate alert file

## Output

```
SiteChecker  |  2026-04-09 09:05:46  |  Timeout: 10s
----------------------------------------------------------------------
[+]  https://www.google.com                        HTTP 200
[-]  https://broken.example.com                    Connection timed out
----------------------------------------------------------------------

Result: 1 UP  |  1 DOWN  |  2 total

Log saved: Z:\Code\SiteChecker\logs\sitechecker_2026-04-09_09-05-46.log
```

- `[+]` = site is up
- `[-]` = site is down or unreachable
