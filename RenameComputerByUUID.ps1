
Write-Output "Renaming computer script starts"
$SqlServer = "sccm-server-hosting-sql-database"
$DBName = "MDT"

Write-Output "Finding ComputerSystemProduct UUID"
$ComputerUUID = (Get-WmiObject Win32_ComputerSystemProduct) | select UUID
Write-Output "Got UUID $($ComputerUUID.UUID)"

Write-Output "Building SQL Connection"
$DBUserName = "<MDT Database Username>"
$DBPassword = "<Database User Password"
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server = $SqlServer; Database = $DBName; User ID = $DBUserName; Password = $DBPassword"

$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = "SELECT * FROM ComputerNameMappings WHERE UUID = '$($ComputerUUID.UUID)'"

Write-Output "Connecting to SQL"
$SqlCmd.Connection = $SqlConnection

$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
Write-Output "Querying for data from SQL"
$SqlAdapter.SelectCommand = $SqlCmd

$DataSet = New-Object System.Data.DataSet
Write-Output "Building up DataSet"
$SQLResult = $SqlAdapter.Fill($DataSet)

# Computernames stored here
$ComputerName = $DataSet.Tables[0] | select NewName

# Rename Creds
# This is the account that will rename computers,
# remember to delegate permissions in Active Directory
$SqlCmd.CommandText = "SELECT * FROM RenameCreds"
$SqlAdapter.SelectCommand = $SqlCmd
$DataSet = New-Object System.Data.DataSet
$SQLResult = $SqlAdapter.Fill($DataSet)
$RenameCreds = $DataSet.Tables[0] 

Write-Output "Closing SQL Connection"
$SqlConnection.Close()

Write-Output "Done with the database, now determining what to do"

if ($($ComputerName.NewName) -eq $null) {
    Write-Output "No data returned form SQL, cannot determine new computername. Matching UUID $($ComputerUUID.UUID) was not found in database."
}
else {
    Write-Output "Data returned from SQL, new computername is $($ComputerName.NewName)"
    Write-Output "Current computername is $env:COMPUTERNAME"

    if ($env:COMPUTERNAME -eq $($ComputerName.NewName)) {
        Write-Output "Current computername is same as new, skip renaming"
    }
    else {
        Write-Output "New computername is different than current, renaming this computer to $($ComputerName.NewName)"

        [string]$p = $($RenameCreds).Password
        [string]$u = $($RenameCreds).Username

        $SecurePassword = ConvertTo-SecureString $p -AsPlainText -Force
        $creds = New-Object System.Management.Automation.PSCredential ($u, $SecurePassword)

        # Test if creds work
        # Start-Process cmd.exe -Credential $creds

        Rename-Computer -ComputerName localhost -NewName $($ComputerName.NewName) -DomainCredential $creds -Verbose -Force -ErrorAction Continue
    }
}

Write-Output "Rename script ends"
