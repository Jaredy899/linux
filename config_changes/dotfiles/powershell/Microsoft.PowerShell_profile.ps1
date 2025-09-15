# Ensure the script only runs interactively
if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows Terminal') {
    # Check if this is a regular SSH session, not SFTP
    if ($env:SSH_CLIENT -and $env:SSH_TTY -or -not $env:SSH_CLIENT) {

        # Place your interactive commands below this line

        # Run fastfetch only in an interactive session
        fastfetch

        # Initialize starship if installed
        if (Get-Command starship -ErrorAction SilentlyContinue) {
            Invoke-Expression (& { starship init powershell })
        }

        # Ensure Terminal-Icons module is installed before importing
        if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
            Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
        }
        Import-Module -Name Terminal-Icons

        # Define aliases and functions
        function ff {
            fastfetch -c all
        }

        function Get-PubIP {
            (Invoke-WebRequest http://ifconfig.me/ip).Content
        }

        function flushdns {
            Clear-DnsClientCache
            Write-Host "DNS has been flushed"
        }

        function apps {
            winget update --all --include-unknown --force
        }

        function jc {
            Invoke-RestMethod jaredcervantes.com/win | Invoke-Expression
        }

        function winutil {
            Invoke-RestMethod christitus.com/win | Invoke-Expression
        }

        function os {
            Invoke-RestMethod jaredcervantes.com/winos | Invoke-Expression
        }

        function bios {
            shutdown.exe /r /fw /f /t 0
        }

        function cr {
            param(
                [Parameter(ValueFromRemainingArguments = $true)]
                [string[]]$Args
            )

            cargo run @Args
        }

        # Git convenience functions
        
        function gb {
            git branch
        }

        function gbd {
            param (
                [Parameter(Mandatory=$true)]
                [string]$branch
            )
            git branch -D $branch
        }

        function gcom {
            param (
                [Parameter(Mandatory=$true)]
                [string]$message
            )
            git add .
            git commit -m $message
        }

        function lazyg {
            param (
                [Parameter(Mandatory=$true)]
                [string]$message
            )
            git add .
            git commit -m $message
            git push
        }

        function newb {
          [CmdletBinding()]
          param(
            [Parameter(Mandatory = $true)]
            [Alias('b')]
            [string] $Branch,

            [Parameter(Mandatory = $true)]
            [Alias('m')]
            [string] $Message
          )

          git checkout -b $Branch
          if ($LASTEXITCODE -ne 0) { return }

          git add .
          git commit -m $Message
          if ($LASTEXITCODE -ne 0) { return }

          git push -u origin $Branch
        }

        function gs {
            $branch = git branch --all --color=never |
                ForEach-Object { $_.Trim().TrimStart('*').Trim() } |
                Sort-Object |
                fzf --prompt="Switch to branch: "

            if ($branch) {
                # Remove "remotes/" prefix if present
                if ($branch -like "remotes/*") {
                    $branch = $branch -replace "^remotes/", ""
                }

                if ($branch -like "origin/*") {
                    $localBranch = $branch -replace "^origin/", ""
                    git switch -c $localBranch --track $branch
                }
                else {
                    git switch $branch
                }
            }
        }

        if (Get-Alias gp -ErrorAction SilentlyContinue) {
            Remove-Item Alias:gp -Force
        }

        function gp {
            param(
                [Parameter(ValueFromRemainingArguments = $true)]
                [string[]]$Args
            )

            git pull @Args
        }

        # Define directory navigation aliases
        function home {
            Set-Location ~
        }
        Set-Alias home home

        function cd.. {
            Set-Location ..
        }
        Set-Alias cd.. cd..

        function .. {
            Set-Location ..
        }

        function ... {
            Set-Location ../..
        }

        function .... {
            Set-Location ../../..
        }

        function ..... {
            Set-Location ../../../..
        }

	function rmd {
    		param (
                    [Parameter(Mandatory = $true)]
                    [string]$Path
    		)
    	        Remove-Item -Path $Path -Recurse -Force
	}


        function mkdirg {
            param(
                [Parameter(Mandatory=$true)]
                [string]$Path
            )
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Set-Location $Path
        }

    } # End of inner if block
} # End of outer if block

# Initialize mise
Invoke-Expression (& { (mise activate powershell | Out-String) })

# Initialize zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })