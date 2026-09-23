#Requires -Version 5.1
<#
.SYNOPSIS
    WPF GUI for validating and formatting international phone numbers, offline.

.DESCRIPTION
    Pick a country and enter a phone number to see whether it is valid, its
    type (Mobile / Landline / VoIP / Toll-Free / etc.), national and
    international (E.164) formatting, IANA time zone(s), and an approximate
    region description - all from offline data. Also supports batch-checking
    a list of numbers and exporting the results to CSV.

    This tool does NOT perform reverse lookups (owner name, live carrier,
    spam reputation, etc.) - those require live, paid, network-based services
    and are out of scope by design. See README.md for why.

    Uses the libphonenumber-csharp library (C# port of Google's libphonenumber):
    https://github.com/twcclegg/libphonenumber-csharp

.NOTES
    First run requires internet access once, to download the ~1-2 MB
    libphonenumber-csharp assembly (and, on Windows PowerShell 5.1, two small
    .NET dependency assemblies) from nuget.org into a local cache folder next
    to this script. Every run after that is fully offline.
#>

[CmdletBinding()]
param()

# ------------------------------------------------------------------
# Setup: locate / download the libphonenumber-csharp assembly
# ------------------------------------------------------------------

$script:CacheDir = Join-Path $PSScriptRoot 'lib'
if (-not (Test-Path $script:CacheDir)) {
    New-Item -ItemType Directory -Path $script:CacheDir -Force | Out-Null
}

function Get-NuGetPackageDll {
    <#
        Downloads a NuGet package's .nupkg from nuget.org's flat-container API,
        extracts the DLL(s) for the requested target framework folder, and
        copies them into the local cache. Returns the full paths of the DLLs
        copied. Uses the newest published version of the package.
    #>
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$FrameworkFolder,   # e.g. 'net8.0' or 'netstandard2.0'
        [Parameter(Mandatory)][string]$CacheDir
    )

    $idLower = $PackageId.ToLowerInvariant()
    $indexUrl = "https://api.nuget.org/v3-flatcontainer/$idLower/index.json"

    Write-Host "Resolving latest version of $PackageId ..."
    $index = Invoke-RestMethod -Uri $indexUrl -UseBasicParsing
    $version = $index.versions | Select-Object -Last 1

    $nupkgUrl = "https://api.nuget.org/v3-flatcontainer/$idLower/$version/$idLower.$version.nupkg"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("nuget_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $nupkgPath = Join-Path $tempDir "$idLower.$version.zip"

    Write-Host "Downloading $PackageId $version ..."
    Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath -UseBasicParsing

    $extractDir = Join-Path $tempDir 'extracted'
    Expand-Archive -Path $nupkgPath -DestinationPath $extractDir -Force

    $libDir = Join-Path (Join-Path $extractDir 'lib') $FrameworkFolder
    if (-not (Test-Path $libDir)) {
        throw "Package '$PackageId' $version has no lib/$FrameworkFolder folder. Cannot continue."
    }

    $dlls = Get-ChildItem -Path $libDir -Filter '*.dll'
    $copied = @()
    foreach ($dll in $dlls) {
        $destPath = Join-Path $CacheDir $dll.Name
        Copy-Item -Path $dll.FullName -Destination $destPath -Force
        $copied += $destPath
    }

    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    return $copied
}

function Initialize-PhoneNumbersLibrary {
    $isPS7Plus = $PSVersionTable.PSVersion.Major -ge 6

    if ($isPS7Plus) {
        $framework = 'net8.0'
        $requiredDlls = @('PhoneNumbers.dll')
    }
    else {
        # Windows PowerShell 5.1 needs the netstandard2.0 build plus two
        # small polyfill dependency assemblies.
        $framework = 'netstandard2.0'
        $requiredDlls = @('PhoneNumbers.dll', 'System.Memory.dll', 'System.Collections.Immutable.dll')
    }

    $missing = $requiredDlls | Where-Object { -not (Test-Path (Join-Path $script:CacheDir $_)) }

    if ($missing) {
        try {
            Write-Host "One-time setup: downloading offline phone-number library ..."
            Get-NuGetPackageDll -PackageId 'libphonenumber-csharp' -FrameworkFolder $framework -CacheDir $script:CacheDir | Out-Null

            if (-not $isPS7Plus) {
                Get-NuGetPackageDll -PackageId 'System.Memory' -FrameworkFolder $framework -CacheDir $script:CacheDir | Out-Null
                Get-NuGetPackageDll -PackageId 'System.Collections.Immutable' -FrameworkFolder $framework -CacheDir $script:CacheDir | Out-Null
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Could not download the required offline phone-number library.`n`nThis is needed once, and requires internet access to nuget.org.`n`nError: $($_.Exception.Message)",
                'Setup Failed',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            exit 1
        }
    }

    foreach ($dll in $requiredDlls) {
        Add-Type -Path (Join-Path $script:CacheDir $dll)
    }
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

Initialize-PhoneNumbersLibrary

$script:PhoneUtil = [PhoneNumbers.PhoneNumberUtil]::GetInstance()
$script:Geocoder = [PhoneNumbers.PhoneNumberOfflineGeocoder]::GetInstance()
$script:TimeZoneMapper = [PhoneNumbers.PhoneNumberToTimeZonesMapper]::GetInstance()

# ------------------------------------------------------------------
# Country list - United Kingdom and United States pinned to the top,
# remaining common countries alphabetical below.
# ------------------------------------------------------------------

$script:Countries = [ordered]@{
    'United Kingdom' = 'GB'
    'United States'  = 'US'
    'Australia'      = 'AU'
    'Belgium'        = 'BE'
    'Brazil'         = 'BR'
    'Canada'         = 'CA'
    'China'          = 'CN'
    'Denmark'        = 'DK'
    'France'         = 'FR'
    'Germany'        = 'DE'
    'India'          = 'IN'
    'Ireland'        = 'IE'
    'Italy'          = 'IT'
    'Japan'          = 'JP'
    'Mexico'         = 'MX'
    'Netherlands'    = 'NL'
    'New Zealand'    = 'NZ'
    'Norway'         = 'NO'
    'Poland'         = 'PL'
    'Portugal'       = 'PT'
    'Singapore'      = 'SG'
    'South Africa'   = 'ZA'
    'Spain'          = 'ES'
    'Sweden'         = 'SE'
    'Switzerland'    = 'CH'
    'UAE'            = 'AE'
}

# Friendly names for PhoneNumbers.PhoneNumberType values
$script:TypeLabels = @{
    'FIXED_LINE'             = 'Landline'
    'MOBILE'                 = 'Mobile'
    'FIXED_LINE_OR_MOBILE'   = 'Landline or Mobile'
    'TOLL_FREE'              = 'Toll-Free'
    'PREMIUM_RATE'           = 'Premium Rate'
    'SHARED_COST'            = 'Shared Cost'
    'VOIP'                   = 'VoIP'
    'PERSONAL_NUMBER'        = 'Personal Number'
    'PAGER'                  = 'Pager'
    'UAN'                    = 'Universal Access Number'
    'VOICEMAIL'              = 'Voicemail'
    'UNKNOWN'                = 'Unknown / Not Recognized'
}

# ------------------------------------------------------------------
# Settings persistence (remembers last-selected country)
# ------------------------------------------------------------------

$script:SettingsPath = Join-Path $PSScriptRoot 'settings.json'

function Get-SavedSettings {
    if (Test-Path $script:SettingsPath) {
        try { return Get-Content -Path $script:SettingsPath -Raw | ConvertFrom-Json }
        catch { return $null }
    }
    return $null
}

function Save-Settings {
    param([string]$LastCountry)
    try {
        @{ LastCountry = $LastCountry } | ConvertTo-Json | Set-Content -Path $script:SettingsPath -Encoding UTF8
    }
    catch { }
}

# ------------------------------------------------------------------
# Shared lookup logic - used by both the single-check UI and batch mode
# ------------------------------------------------------------------

function Get-PhoneNumberDetails {
    param(
        [Parameter(Mandatory)][string]$RawNumber,
        [Parameter(Mandatory)][string]$RegionCode,
        [Parameter(Mandatory)][string]$CountryName
    )

    $result = [ordered]@{
        InputNumber   = $RawNumber
        Country       = $CountryName
        Valid         = $null
        Possible      = $null
        NumberType    = ''
        National      = ''
        International = ''
        TimeZones     = ''
        Region        = ''
        Notes         = ''
        Error         = ''
    }

    try {
        $parsed = $script:PhoneUtil.Parse($RawNumber, $RegionCode)

        $isValid = $script:PhoneUtil.IsValidNumber($parsed)
        $isPossible = $script:PhoneUtil.IsPossibleNumber($parsed)
        $result.Valid = $isValid
        $result.Possible = $isPossible

        $numberTypeRaw = $script:PhoneUtil.GetNumberType($parsed).ToString()
        $result.NumberType = if ($script:TypeLabels.ContainsKey($numberTypeRaw)) { $script:TypeLabels[$numberTypeRaw] } else { $numberTypeRaw }

        $result.National = $script:PhoneUtil.Format($parsed, [PhoneNumbers.PhoneNumberFormat]::NATIONAL)
        $result.International = $script:PhoneUtil.Format($parsed, [PhoneNumbers.PhoneNumberFormat]::INTERNATIONAL)

        $description = $script:Geocoder.GetDescriptionForNumber($parsed, [PhoneNumbers.Locale]::English)
        $result.Region = if ([string]::IsNullOrWhiteSpace($description)) { $CountryName } else { $description }

        try {
            $tz = $script:TimeZoneMapper.GetTimeZonesForNumber($parsed)
            if ($tz -and $tz.Count -gt 0 -and -not ($tz.Count -eq 1 -and $tz[0] -eq 'Etc/Unknown')) {
                $result.TimeZones = ($tz -join ', ')
            }
        }
        catch { }

        $notes = New-Object System.Collections.Generic.List[string]
        if (-not $isPossible) {
            $notes.Add("Not even a possible number for $CountryName - check the digits and selected country.")
        }
        elseif (-not $isValid) {
            $notes.Add("Correctly shaped but not a recognized valid $CountryName number - can indicate a spoofed or mistyped caller ID.")
        }
        if ($numberTypeRaw -eq 'VOIP') {
            $notes.Add("VoIP line - cheap to provision and easy to spoof; caller identity can't be confirmed from the number alone.")
        }
        if ($numberTypeRaw -eq 'PREMIUM_RATE') {
            $notes.Add("Premium-rate number - calling or returning this call may incur extra charges.")
        }
        $result.Notes = ($notes -join ' ')
    }
    catch [PhoneNumbers.NumberParseException] {
        $result.Error = "Could not parse as a $CountryName number: $($_.Exception.Message)"
    }
    catch {
        $result.Error = "Unexpected error: $($_.Exception.Message)"
    }

    return [PSCustomObject]$result
}

# ------------------------------------------------------------------
# Main window XAML
# ------------------------------------------------------------------

[xml]$mainXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Phone Number Validator" Height="640" Width="460"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        FontFamily="Segoe UI" FontSize="13">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Country" FontWeight="SemiBold" Margin="0,0,0,4"/>
        <ComboBox x:Name="CountryCombo" Grid.Row="1" Height="28" Margin="0,0,0,12"/>

        <TextBlock Grid.Row="2" Text="Phone Number" FontWeight="SemiBold" Margin="0,0,0,4"/>
        <TextBox x:Name="NumberBox" Grid.Row="3" Height="28" Margin="0,0,0,4"
                 VerticalContentAlignment="Center"/>
        <TextBlock x:Name="HintText" Grid.Row="4"
                   Foreground="Gray" FontSize="11" Margin="0,0,0,10" TextWrapping="Wrap"/>

        <StackPanel Grid.Row="5">
            <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                <Button x:Name="CheckButton" Content="Check Number" Height="32" Width="150" Margin="0,0,8,0"/>
                <Button x:Name="BatchButton" Content="Batch Check..." Height="32" Width="150"/>
            </StackPanel>

            <TextBlock x:Name="ErrorText" Foreground="Red" TextWrapping="Wrap" Margin="0,0,0,10" Visibility="Collapsed"/>

            <Border BorderBrush="#CCCCCC" BorderThickness="1" Padding="12" CornerRadius="4">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="130"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="50"/>
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" Grid.Column="0" Text="Valid:" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBlock x:Name="ValidText" Grid.Row="0" Grid.Column="1" Margin="0,0,0,8"/>

                    <TextBlock Grid.Row="1" Grid.Column="0" Text="Number Type:" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBlock x:Name="TypeText" Grid.Row="1" Grid.Column="1" Margin="0,0,0,8"/>

                    <TextBlock Grid.Row="2" Grid.Column="0" Text="National Format:" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBlock x:Name="NationalText" Grid.Row="2" Grid.Column="1" Margin="0,0,0,8"/>
                    <Button x:Name="CopyNationalButton" Grid.Row="2" Grid.Column="2" Content="Copy" Height="22" Padding="2,0" Margin="4,0,0,8"/>

                    <TextBlock Grid.Row="3" Grid.Column="0" Text="International:" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBlock x:Name="InternationalText" Grid.Row="3" Grid.Column="1" Margin="0,0,0,8"/>
                    <Button x:Name="CopyInternationalButton" Grid.Row="3" Grid.Column="2" Content="Copy" Height="22" Padding="2,0" Margin="4,0,0,8"/>

                    <TextBlock Grid.Row="4" Grid.Column="0" Text="Time Zone(s):" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBlock x:Name="TimeZoneText" Grid.Row="4" Grid.Column="1" Grid.ColumnSpan="2" Margin="0,0,0,8" TextWrapping="Wrap"/>

                    <TextBlock Grid.Row="5" Grid.Column="0" Text="Region:" FontWeight="SemiBold"/>
                    <TextBlock x:Name="RegionText" Grid.Row="5" Grid.Column="1" Grid.ColumnSpan="2" TextWrapping="Wrap"/>
                </Grid>
            </Border>

            <TextBlock x:Name="NotesText" Foreground="#B36B00" TextWrapping="Wrap" Margin="0,10,0,0" FontSize="12"/>
        </StackPanel>
    </Grid>
</Window>
'@

# ------------------------------------------------------------------
# Batch window XAML
# ------------------------------------------------------------------

[xml]$batchXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Batch Phone Number Check" Height="560" Width="760"
        WindowStartupLocation="CenterOwner" FontFamily="Segoe UI" FontSize="13">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="120"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" TextWrapping="Wrap" Margin="0,0,0,8"
                    Text="Paste one number per line. Optionally add a country after a comma to override the default below, e.g. '+1 415 555 0100' or '020 7946 0958,GB'."/>

        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,8">
            <TextBlock Text="Default country for lines with no country specified:" VerticalAlignment="Center" Margin="0,0,8,0"/>
            <ComboBox x:Name="DefaultCountryCombo" Width="180"/>
        </StackPanel>

        <TextBox x:Name="BatchInputBox" Grid.Row="2" AcceptsReturn="True" TextWrapping="NoWrap"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Margin="0,0,0,8"/>

        <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,0,0,8">
            <Button x:Name="RunBatchButton" Content="Run" Width="100" Height="30" Margin="0,0,8,0"/>
            <Button x:Name="ExportCsvButton" Content="Export to CSV..." Width="140" Height="30"/>
        </StackPanel>

        <DataGrid x:Name="ResultsGrid" Grid.Row="4" AutoGenerateColumns="True" IsReadOnly="True"
                  CanUserAddRows="False" GridLinesVisibility="Horizontal" AlternatingRowBackground="#F5F5F5"/>
    </Grid>
</Window>
'@

# ------------------------------------------------------------------
# Build main window
# ------------------------------------------------------------------

$reader = New-Object System.Xml.XmlNodeReader $mainXaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$countryCombo         = $window.FindName('CountryCombo')
$numberBox            = $window.FindName('NumberBox')
$hintText             = $window.FindName('HintText')
$checkButton          = $window.FindName('CheckButton')
$batchButton          = $window.FindName('BatchButton')
$errorText            = $window.FindName('ErrorText')
$validText            = $window.FindName('ValidText')
$typeText             = $window.FindName('TypeText')
$nationalText         = $window.FindName('NationalText')
$internationalText    = $window.FindName('InternationalText')
$timeZoneText         = $window.FindName('TimeZoneText')
$regionText           = $window.FindName('RegionText')
$notesText            = $window.FindName('NotesText')
$copyNationalButton   = $window.FindName('CopyNationalButton')
$copyInternationalButton = $window.FindName('CopyInternationalButton')

foreach ($name in $script:Countries.Keys) {
    $countryCombo.Items.Add($name) | Out-Null
}

$savedSettings = Get-SavedSettings
$startIndex = 0
if ($savedSettings -and $savedSettings.LastCountry -and $script:Countries.Contains($savedSettings.LastCountry)) {
    $startIndex = [array]::IndexOf(@($script:Countries.Keys), $savedSettings.LastCountry)
    if ($startIndex -lt 0) { $startIndex = 0 }
}
$countryCombo.SelectedIndex = $startIndex

function Update-HintText {
    $countryName = $countryCombo.SelectedItem
    if (-not $countryName) { return }
    $regionCode = $script:Countries[$countryName]
    try {
        $example = $script:PhoneUtil.GetExampleNumber($regionCode)
        if ($example) {
            $formatted = $script:PhoneUtil.Format($example, [PhoneNumbers.PhoneNumberFormat]::NATIONAL)
            $hintText.Text = "e.g. $formatted  (or with country code: $($script:PhoneUtil.Format($example, [PhoneNumbers.PhoneNumberFormat]::INTERNATIONAL)))"
        }
        else {
            $hintText.Text = "Enter with or without the country code."
        }
    }
    catch {
        $hintText.Text = "Enter with or without the country code."
    }
}
Update-HintText

function Clear-Results {
    $errorText.Visibility = 'Collapsed'
    $errorText.Text = ''
    $validText.Text = ''
    $typeText.Text = ''
    $nationalText.Text = ''
    $internationalText.Text = ''
    $timeZoneText.Text = ''
    $regionText.Text = ''
    $notesText.Text = ''
}

function Show-Error {
    param([string]$Message)
    $errorText.Text = $Message
    $errorText.Visibility = 'Visible'
}

function Invoke-SingleCheck {
    Clear-Results

    $countryName = $countryCombo.SelectedItem
    $regionCode = $script:Countries[$countryName]
    $rawNumber = $numberBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($rawNumber)) {
        Show-Error "Enter a phone number first."
        return
    }

    $details = Get-PhoneNumberDetails -RawNumber $rawNumber -RegionCode $regionCode -CountryName $countryName

    if ($details.Error) {
        Show-Error $details.Error
        return
    }

    $validText.Text = if ($details.Valid) { 'Yes' } else { 'No' }
    $validText.Foreground = if ($details.Valid) { [System.Windows.Media.Brushes]::Green } else { [System.Windows.Media.Brushes]::Red }
    $typeText.Text = $details.NumberType
    $nationalText.Text = $details.National
    $internationalText.Text = $details.International
    $timeZoneText.Text = if ($details.TimeZones) { $details.TimeZones } else { '(not available for this number)' }
    $regionText.Text = $details.Region
    $notesText.Text = $details.Notes
}

# Country change: refresh hint text and persist selection
$countryCombo.Add_SelectionChanged({
    Update-HintText
    if ($countryCombo.SelectedItem) {
        Save-Settings -LastCountry $countryCombo.SelectedItem
    }
})

# Live "as you type" formatting
$script:IsFormatting = $false
$numberBox.Add_TextChanged({
    if ($script:IsFormatting) { return }
    $script:IsFormatting = $true
    try {
        $countryName = $countryCombo.SelectedItem
        if (-not $countryName) { return }
        $regionCode = $script:Countries[$countryName]
        $raw = $numberBox.Text

        if ([string]::IsNullOrEmpty($raw)) { return }

        $formatter = $script:PhoneUtil.GetAsYouTypeFormatter($regionCode)
        $formatter.Clear()
        $formatted = ''
        foreach ($ch in $raw.ToCharArray()) {
            if ($ch -eq '+' -or [char]::IsDigit($ch)) {
                $formatted = $formatter.InputDigit($ch)
            }
        }
        if ($formatted -and $formatted -ne $numberBox.Text) {
            $numberBox.Text = $formatted
            $numberBox.CaretIndex = $numberBox.Text.Length
        }
    }
    catch {
        # If formatting fails for any reason, just leave the raw text as typed.
    }
    finally {
        $script:IsFormatting = $false
    }
})

$numberBox.Add_KeyDown({
    if ($_.Key -eq [System.Windows.Input.Key]::Return) {
        Invoke-SingleCheck
    }
})

$checkButton.Add_Click({ Invoke-SingleCheck })

$copyNationalButton.Add_Click({
    if ($nationalText.Text) {
        try { [System.Windows.Clipboard]::SetText($nationalText.Text) } catch { }
    }
})
$copyInternationalButton.Add_Click({
    if ($internationalText.Text) {
        try { [System.Windows.Clipboard]::SetText($internationalText.Text) } catch { }
    }
})

# ------------------------------------------------------------------
# Batch window logic
# ------------------------------------------------------------------

$batchButton.Add_Click({
    $batchReader = New-Object System.Xml.XmlNodeReader $batchXaml
    $batchWindow = [Windows.Markup.XamlReader]::Load($batchReader)
    $batchWindow.Owner = $window

    $defaultCountryCombo = $batchWindow.FindName('DefaultCountryCombo')
    $batchInputBox       = $batchWindow.FindName('BatchInputBox')
    $runBatchButton      = $batchWindow.FindName('RunBatchButton')
    $exportCsvButton     = $batchWindow.FindName('ExportCsvButton')
    $resultsGrid         = $batchWindow.FindName('ResultsGrid')

    foreach ($name in $script:Countries.Keys) {
        $defaultCountryCombo.Items.Add($name) | Out-Null
    }
    $defaultCountryCombo.SelectedItem = $countryCombo.SelectedItem

    $script:BatchResults = @()

    $runBatchButton.Add_Click({
        $lines = $batchInputBox.Text -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if (-not $lines -or $lines.Count -eq 0) {
            [System.Windows.MessageBox]::Show('Paste at least one phone number first.', 'Batch Check') | Out-Null
            return
        }

        $defaultCountryName = $defaultCountryCombo.SelectedItem
        if (-not $defaultCountryName) { $defaultCountryName = 'United Kingdom' }
        $defaultRegionCode = $script:Countries[$defaultCountryName]

        $results = New-Object System.Collections.Generic.List[object]
        foreach ($line in $lines) {
            $parts = $line -split ',', 2
            $numberPart = $parts[0].Trim()
            $countryPart = if ($parts.Count -gt 1) { $parts[1].Trim().ToUpperInvariant() } else { '' }

            if ($countryPart) {
                $matchedCountry = $script:Countries.Keys | Where-Object { $script:Countries[$_] -eq $countryPart } | Select-Object -First 1
                if ($matchedCountry) {
                    $regionCode = $countryPart
                    $countryName = $matchedCountry
                }
                else {
                    $regionCode = $defaultRegionCode
                    $countryName = $defaultCountryName
                }
            }
            else {
                $regionCode = $defaultRegionCode
                $countryName = $defaultCountryName
            }

            $details = Get-PhoneNumberDetails -RawNumber $numberPart -RegionCode $regionCode -CountryName $countryName
            $results.Add($details)
        }

        $script:BatchResults = $results
        $resultsGrid.ItemsSource = $results
    })

    $exportCsvButton.Add_Click({
        if (-not $script:BatchResults -or $script:BatchResults.Count -eq 0) {
            [System.Windows.MessageBox]::Show('Run a batch check first.', 'Export to CSV') | Out-Null
            return
        }

        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.Filter = 'CSV files (*.csv)|*.csv'
        $saveDialog.FileName = 'PhoneNumberBatchResults.csv'
        if ($saveDialog.ShowDialog()) {
            $script:BatchResults | Export-Csv -Path $saveDialog.FileName -NoTypeInformation -Encoding UTF8
            [System.Windows.MessageBox]::Show("Saved to $($saveDialog.FileName)", 'Export to CSV') | Out-Null
        }
    })

    $batchWindow.ShowDialog() | Out-Null
})

$window.ShowDialog() | Out-Null