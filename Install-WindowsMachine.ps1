Param
(
    [Switch]
    $prepOS,

    [Switch]
    $tools,

    [Switch]
    $graphictools,

    [Switch]
    $dev,

    [Switch]
    $nohyperv,

    [Switch]
    $installVs,

    [Parameter(Mandatory=$False)]
    [ValidateSet("2017")]
    $vsVersion = "2017",

    [Parameter(Mandatory=$False)]
    [ValidateSet("Community", "Professional", "Enterprise")]
    $vsEdition = "Community",

    [Switch]
    $vsext,

    [Switch]
    $vscodeext
)



#
# Simple Parameter validation
#
if( $prepOS -and ($tools -or $graphictools -or $dev -or $installVs -or $vsext -or $vscodeext) ) {
    throw "Running the script with -prepOS does not allow you to use any other switches. First run -prepOS and then run with any other allowed combination of switches!"
}

if( $dev -and $installVs )
{
    throw "Visual Studio and developer tools need to be installed separately. First run with -installVs and then run with -dev!"
}

#
# [prepOS] Installing Operating System Components as well as chocolatey itself. Needs to happen before ANY other runs!
#
if( $prepOS ) 
{
    Set-ExecutionPolicy unrestricted

    # Enable Console Prompting for PowerShell
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name "ConsolePrompting" -Value $True

    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

    Enable-WindowsOptionalFeature -FeatureName NetFx4-AdvSrvs -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName NetFx4Extended-ASPNET45 -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName Windows-Identity-Foundation -Online -NoRestart

    if( ! $nohyperv ) {
        Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online -NoRestart
        Enable-WindowsOptionalFeature -FeatureName Containers -Online -NoRestart
    }

    Write-Information ""
    Write-Information "Installation of OS components completed, please restart your computer once ready!"
    Write-Information ""

    Exit
}

#
# Function for refreshing environment variables
#
function RefreshEnvironment() {
    foreach($envLevel in "Machine","User") {
        [Environment]::GetEnvironmentVariables($envLevel).GetEnumerator() | ForEach-Object {
            # For Path variables, append the new values, if they're not already in there
            if($_.Name -match 'Path$') { 
               $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -Split ';' | Select-Object -Unique) -Join ';'
            }
            $_
         } | Set-Content -Path { "Env:$($_.Name)" }
    }
}

#
# Function to create a path if it does not exist
#
function CreatePathIfNotExists($pathName) {
    if(!(Test-Path -Path $pathName)) {
        New-Item -ItemType directory -Path $pathName
    }
}

#
# Function to install VSIX extensions
#
$vsixInstallerCommand2017 = "C:\Program Files (x86)\Microsoft Visual Studio\2017\$vsEdition\Common7\IDE\VsixInstaller.exe"
$vsixInstallerCommandGeneralArgs = " /q /a "

function InstallVSExtension($extensionUrl, $extensionFileName, $vsVersion) {
    
    Write-Host "Installing extension " $extensionFileName
    
    # Select the appropriate VSIX installer
    if($vsVersion -eq "2017") {
        $vsixInstallerCommand = $vsixInstallerCommand2017
    }

    # Download the extension
    Invoke-WebRequest $extensionUrl -OutFile $extensionFileName

    # Quiet Install of the Extension
    $proc = Start-Process -FilePath "$vsixInstallerCommand" -ArgumentList ($vsixInstallerCommandGeneralArgs + $extensionFileName) -PassThru
    $proc.WaitForExit()
    if ( $proc.ExitCode -ne 0 ) {
        Write-Host "Unable to install extension " $extensionFileName " due to error " $proc.ExitCode -ForegroundColor Red
    }

    # Delete the downloaded extension file from the local system
    Remove-Item $extensionFileName
}


#
# [tools] Tools needed on every machine
#

if( $tools ) {

    choco install -y lastpass

    choco install -y 7zip

    choco install -y adobereader

    choco install -y googlechrome

    choco install -y firefox -installArgs l=en-US
	
	choco install -y telegram.install

    choco install -y spotify
    
	choco install -y notepadplusplus.install
}

if( $graphictools ) {

    choco install -y adobe-creative-cloud
}


#
# [installVs] Installing a version of Visual Studio (based on Chocolatey)
#
if($installVs) {
    if($vsVersion -eq "2017") {
        switch ($vsEdition) {
            "Community" {
                choco install visualstudio2017community -y --package-parameters "--add Microsoft.VisualStudio.Workload.Azure --add Microsoft.VisualStudio.Workload.NetWeb --add Microsoft.VisualStudio.Workload.Node --add --includeRecommended --includeOptional --passive --locale en-US"
            }
            "Professional" {
                choco install visualstudio2017professional -y --package-parameters "--allWorkloads --includeRecommended --includeOptional --passive --locale en-US"
            }            
            "Enterprise" {
                choco install visualstudio2017enterprise -y --package-parameters "--allWorkloads --includeRecommended --includeOptional --passive --locale en-US"
            }
        }
    }
}


#
# [dev] Developer Tools needed on every dev-machine
#
if( $dev )
{
    #
    # Phase #1 will install the the basic tools and runtimes
    #
	
	choco install -y conemu 

    choco install -y --allowemptychecksum putty

    choco install -y filezilla

    choco install -y visualstudiocode

    choco install -y nodejs.install

    choco install -y git.install

    choco install -y poshgit
	
	choco install -y tortoisegit

    choco install -y postman
	
	choco install -y azure-cli

    if ( $nohyperv ) {

        choco install -y virtualbox

        choco install -y docker
        
        choco install -y docker-machine
        
        choco install -y docker-compose

    }
    else {

        choco install -y docker-for-windows

    }    

    choco install -y nuget.commandline
	
	choco install -y sql-server-management-studio

	choco install -y pgadmin4
}


if( $vsext -and ($vsVersion -eq "2017") ) {

    # Refreshing the environment path variables
    RefreshEnvironment
	
	#ReSharper
	choco install -y resharper

    # Typewriter
    # https://marketplace.visualstudio.com/items?itemName=frhagn.Typewriter
    InstallVSExtension -extensionUrl "https://frhagn.gallerycdn.vsassets.io/extensions/frhagn/typewriter/1.18.0/1516093812046/Typewriter-1.18.0.vsix" `
                       -extensionFileName "Typewriter-1.18.0.vsix" -vsVersion $vsVersion

}


#
# Visual Studio Code Extensions
#
if ( $vscodeext ) {

    # Refreshing the environment path variables
    RefreshEnvironment

    # Start installing all extensions

    code --install-extension ms-vscode.csharp
    
    code --install-extension ms-vscode.PowerShell

    code --install-extension ms-vscode.node-debug

    code --install-extension ms-vscode.Theme-MarkdownKit
    
    code --install-extension ms-vscode.Theme-MaterialKit

    code --install-extension msjsdiag.debugger-for-chrome
    
    code --install-extension msjsdiag.debugger-for-edge
}