####### The starting point for the script is the bottom #######

###############################################################
########################## FUNCTIONS ##########################
###############################################################
function All-Command
{
	If (!(Test-Path "*.sln"))
	{
		return
	}

	$msBuild = FindMSBuild
	$msBuildArguments = "/t:Rebuild /nr:false"
	if ($msBuild -eq $null)
	{
		echo "Unable to locate an appropriate version of MSBuild."
	}
	else
	{
		$proc = Start-Process $msBuild $msBuildArguments -NoNewWindow -PassThru -Wait
		if ($proc.ExitCode -ne 0)
		{
			echo "Build failed. If just the development tools failed to build, try installing Visual Studio. You may also still be able to run the game."
		}
		else
		{
			echo "Build succeeded."
		}
	}
}

function Clean-Command
{
	If (!(Test-Path "*.sln"))
	{
		return
	}

	$msBuild = FindMSBuild
	$msBuildArguments = "/t:Clean /nr:false"
	if ($msBuild -eq $null)
	{
		echo "Unable to locate an appropriate version of MSBuild."
	}
	else
	{
		$proc = Start-Process $msBuild $msBuildArguments -NoNewWindow -PassThru -Wait
		rm *.dll
		rm *.dll.config
		rm mods/*/*.dll
		rm *.pdb
		rm mods/*/*.pdb
		rm *.exe
		rm ./*/bin -r
		rm ./*/obj -r
		echo "Clean complete."
	}
}

function Version-Command
{
	if ($command.Length -gt 1)
	{
		$version = $command[1]
	}
	elseif (Get-Command 'git' -ErrorAction SilentlyContinue)
	{
		$gitRepo = git rev-parse --is-inside-work-tree
		if ($gitRepo)
		{
			$version = git name-rev --name-only --tags --no-undefined HEAD 2>$null
			if ($version -eq $null)
			{
				$version = "git-" + (git rev-parse --short HEAD)
			}
		}
		else
		{
			echo "Not a git repository. The version will remain unchanged."
		}
	}
	else
	{
		echo "Unable to locate Git. The version will remain unchanged."
	}

	if ($version -ne $null)
	{
		$mod = "mods/" + $modID + "/mod.yaml"
		$replacement = (gc $mod) -Replace "Version:.*", ("Version: {0}" -f $version)
		sc $mod $replacement

		$prefix = $(gc $mod) | Where { $_.ToString().EndsWith(": User") }
		if ($prefix -and $prefix.LastIndexOf("/") -ne -1)
		{
			$prefix = $prefix.Substring(0, $prefix.LastIndexOf("/"))
		}
		$replacement = (gc $mod) -Replace ".*: User", ("{0}/{1}: User" -f $prefix, $version)
		sc $mod $replacement

		echo ("Version strings set to '{0}'." -f $version)
	}
}

function Test-Command
{
	if (Test-Path $utilityPath)
	{
		echo "Testing $modID mod MiniYAML"
		Invoke-Expression "$utilityPath $modID --check-yaml"
	}
	else
	{
		UtilityNotFound
	}
}

function Check-Command
{
	if (Test-Path $utilityPath)
	{
		echo "Checking for explicit interface violations..."
		Invoke-Expression "$utilityPath $modID --check-explicit-interfaces"

		echo "Checking for code style violations in OpenRA.Mods.$modID..."
		Invoke-Expression "$utilityPath $modID --check-code-style OpenRA.Mods.$modID"
	}
	else
	{
		UtilityNotFound
	}
}

function Check-Scripts-Command
{
	if ((Get-Command "luac.exe" -ErrorAction SilentlyContinue) -ne $null)
	{
		echo "Testing Lua scripts..."
		foreach ($script in ls "mods/*/maps/*/*.lua")
		{
			luac -p $script
		}
		echo "Check completed!"
	}
	else
	{
		echo "luac.exe could not be found. Please install Lua."
	}
}

function Docs-Command
{
	if (Test-Path $utilityPath)
	{
		Invoke-Expression "$utilityPath $modID --docs | Out-File -Encoding 'UTF8' DOCUMENTATION.md"
		Invoke-Expression "$utilityPath $modID --lua-docs | Out-File -Encoding 'UTF8' Lua-API.md"
		echo "Docs generated."
	}
	else
	{
		UtilityNotFound
	}
}

function FindMSBuild
{
	$key = "HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\4.0"
	$property = Get-ItemProperty $key -ErrorAction SilentlyContinue
	if ($property -eq $null -or $property.MSBuildToolsPath -eq $null)
	{
		return $null
	}

	$path = Join-Path $property.MSBuildToolsPath -ChildPath "MSBuild.exe"
	if (Test-Path $path)
	{
		return $path
	}

	return $null
}

function UtilityNotFound
{
	echo "OpenRA.Utility.exe could not be found. Build the project first using the `"all`" command."
}

function WaitForInput
{
	echo "Press enter to continue."
	while ($true)
	{
		if ([System.Console]::KeyAvailable)
		{
			exit
		}
		Start-Sleep -Milliseconds 50
	}
}

###############################################################
############################ Main #############################
###############################################################
if ($args.Length -eq 0)
{
	echo "Command list:"
	echo ""
	echo "  all             Builds the game, its development tools and the mod dlls."
	echo "  version         Sets the version strings for all mods to the latest"
	echo "                  version for the current Git branch."
	echo "  clean           Removes all built and copied files."
	echo "                  from the mods and the engine directories."
	echo "  test            Tests the mod's MiniYAML for errors."
	echo "  check           Checks .cs files for StyleCop violations."
	echo "  check-scripts   Checks .lua files for syntax errors."
	echo "  docs            Generates the trait and Lua API documentation."
	echo ""
	$command = (Read-Host "Enter command").Split(' ', 2)
}
else
{
	$command = $args
}

# Load the environment variables from the config file
# and get the mod ID from the local environment variable
$reader = [System.IO.File]::OpenText("mod.config")
while($null -ne ($line = $reader.ReadLine()))
{
	if ($line.StartsWith("MOD_ID"))
	{
		$env:MOD_ID = $line.Replace('MOD_ID=', '').Replace('"', '')
		$modID = $env:MOD_ID
	}

	if ($line.StartsWith("INCLUDE_DEFAULT_MODS"))
	{
		$env:INCLUDE_DEFAULT_MODS = $line.Replace('INCLUDE_DEFAULT_MODS=', '').Replace('"', '')
	}

	if ($line.StartsWith("ENGINE_VERSION"))
	{
		$env:ENGINE_VERSION = $line.Replace('ENGINE_VERSION=', '').Replace('"', '')
	}

	if ($line.StartsWith("AUTOMATIC_ENGINE_MANAGEMENT"))
	{
		$env:AUTOMATIC_ENGINE_MANAGEMENT = $line.Replace('AUTOMATIC_ENGINE_MANAGEMENT=', '').Replace('"', '')
	}

	if ($line.StartsWith("AUTOMATIC_ENGINE_SOURCE"))
	{
		$env:AUTOMATIC_ENGINE_SOURCE = $line.Replace('AUTOMATIC_ENGINE_SOURCE=', '').Replace('"', '')
	}

	if ($line.StartsWith("AUTOMATIC_ENGINE_EXTRACT_DIRECTORY"))
	{
		$env:AUTOMATIC_ENGINE_EXTRACT_DIRECTORY = $line.Replace('AUTOMATIC_ENGINE_EXTRACT_DIRECTORY=', '').Replace('"', '')
	}

	if ($line.StartsWith("AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME"))
	{
		$env:AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME = $line.Replace('AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME=', '').Replace('"', '')
	}

	if ($line.StartsWith("ENGINE_DIRECTORY"))
	{
		$env:ENGINE_DIRECTORY = $line.Replace('ENGINE_DIRECTORY=', '').Replace('"', '')
	}
}

$env:MOD_SEARCH_PATHS = (Get-Item -Path ".\" -Verbose).FullName + "\mods"
if ($env:INCLUDE_DEFAULT_MODS -eq "True")
{
	$env:MOD_SEARCH_PATHS = $env:MOD_SEARCH_PATHS + ",./mods"
}

# Run the same command on the engine's make file
if ($command -eq "all" -or $command -eq "clean")
{
	$templateDir = $pwd.Path
	$versionFile = $env:ENGINE_DIRECTORY + "/VERSION"
	if ((Test-Path $versionFile) -and [System.IO.File]::OpenText($versionFile).ReadLine() -eq $env:ENGINE_VERSION)
	{
		cd $env:ENGINE_DIRECTORY
		Invoke-Expression ".\make.cmd $command"
		echo ""
		cd $templateDir
	}
	elseif ($env:AUTOMATIC_ENGINE_MANAGEMENT -ne "True")
	{
		echo "Automatic engine management is disabled."
		echo "Please manually update the engine to version $env:ENGINE_VERSION."
		WaitForInput
	}
	else
	{
		echo "OpenRA engine version $env:ENGINE_VERSION is required."

		if (Test-Path $env:ENGINE_DIRECTORY)
		{
			if ((Test-Path $versionFile) -and [System.IO.File]::OpenText($versionFile).ReadLine() -ne "")
			{
				echo "Deleting engine version $currentEngine."
			}
			else
			{
				echo "Deleting existing engine (unknown version)."
			}

			rm $env:ENGINE_DIRECTORY -r
		}

		echo "Downloading engine..."

		if (Test-Path $env:AUTOMATIC_ENGINE_EXTRACT_DIRECTORY)
		{
			rm $env:AUTOMATIC_ENGINE_EXTRACT_DIRECTORY -r
		}

		$url = $env:AUTOMATIC_ENGINE_SOURCE
		$url = $url.Replace("$", "").Replace("{ENGINE_VERSION}", $env:ENGINE_VERSION)

		mkdir $env:AUTOMATIC_ENGINE_EXTRACT_DIRECTORY > $null
		$dlPath = Join-Path $pwd (Split-Path -leaf $env:AUTOMATIC_ENGINE_EXTRACT_DIRECTORY)
		$dlPath = Join-Path $dlPath (Split-Path -leaf $env:AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME)

		$client = new-object System.Net.WebClient 
		$client.DownloadFile($url, $dlPath)

		Add-Type -assembly "system.io.compression.filesystem"
		[io.compression.zipfile]::ExtractToDirectory($dlPath, $env:AUTOMATIC_ENGINE_EXTRACT_DIRECTORY)
		rm $dlPath

		$extractedDir = Get-ChildItem -Recurse | ?{ $_.ToString().StartsWith("OpenRA-") -and $_.PSIsContainer }
		Move-Item $extractedDir.FullName -Destination $templateDir
		Rename-Item $extractedDir.Name (Split-Path -leaf $env:ENGINE_DIRECTORY)

		rm $env:AUTOMATIC_ENGINE_EXTRACT_DIRECTORY -r

		cd $env:ENGINE_DIRECTORY
		Invoke-Expression ".\make.cmd version $env:ENGINE_VERSION"
		Invoke-Expression ".\make.cmd $command"
		echo ""
		cd $templateDir
	}
}

$utilityPath = $env:ENGINE_DIRECTORY + "/OpenRA.Utility.exe"

$execute = $command
if ($command.Length -gt 1)
{
	$execute = $command[0]
}

switch ($execute)
{
	"all" { All-Command }
	"version" { Version-Command }
	"clean" { Clean-Command }
	"test" { Test-Command }
	"check" { Check-Command }
	"check-scripts" { Check-Scripts-Command }
	"docs" { Docs-Command }
	Default { echo ("Invalid command '{0}'" -f $command) }
}

# In case the script was called without any parameters we keep the window open
if ($args.Length -eq 0)
{
	WaitForInput
}
