[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')       | out-null
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework')      | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')          | out-null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | out-null

$t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
add-type -name win -member $t -namespace native
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)

$icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\cmmon32.exe")    

 

################################################################################################################################"
# ACTIONS FROM THE SYSTRAY
################################################################################################################################"


# ----------------------------------------------------
# Part - Add the systray menu
# ----------------------------------------------------        

 

$Main_Tool_Icon = New-Object System.Windows.Forms.NotifyIcon
$Main_Tool_Icon.Text = "Keep Awake Tool"
$Main_Tool_Icon.Icon = $icon
$Main_Tool_Icon.Visible = $true

$Menu_Start = New-Object System.Windows.Forms.MenuItem
$Menu_Start.Enabled = $false
$Menu_Start.Text = "Start"

$Menu_Stop = New-Object System.Windows.Forms.MenuItem
$Menu_Stop.Enabled = $true
$Menu_Stop.Text = "Stop"

$Menu_Exit = New-Object System.Windows.Forms.MenuItem
$Menu_Exit.Text = "Exit"

$Menu_Timer = New-Object System.Windows.Forms.MenuItem
$Menu_Timer.Text = "Timer"

$contextmenu = New-Object System.Windows.Forms.ContextMenu
$Main_Tool_Icon.ContextMenu = $contextmenu
$Main_Tool_Icon.contextMenu.MenuItems.AddRange($Menu_Start)
$Main_Tool_Icon.contextMenu.MenuItems.AddRange($Menu_Timer)
$Main_Tool_Icon.contextMenu.MenuItems.AddRange($Menu_Stop)
$Main_Tool_Icon.contextMenu.MenuItems.AddRange($Menu_Exit)

# ---------------------------------------------------------------------
# Action to keep system awake
# ---------------------------------------------------------------------

 

$keepAwakeScript = {
    $WShell = New-Object -com "Wscript.Shell"
    while($True){
    $WShell.sendkeys("{SCROLLLOCK}")
        Start-Sleep -Milliseconds 100
        $WShell.sendkeys("{SCROLLLOCK}")
        Start-Sleep -Seconds 59

    }
}
 

function Kill-Tree {
    Param([int]$ppid)
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $ppid } | ForEach-Object { Kill-Tree $_.ProcessId }
    Stop-Process -Id $ppid
}

 

Start-Job -ScriptBlock $keepAwakeScript -Name "keepAwake"

# ---------------------------------------------------------------------
# Action when selecting the timer option from the systray
# ---------------------------------------------------------------------
function timerPrompt { 

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Timer Entry Form'
    $form.Size = New-Object System.Drawing.Size(300, 200)
    $form.StartPosition = 'CenterScreen'

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75, 120)
    $okButton.Size = New-Object System.Drawing.Size(75, 23)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(150, 120)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 23)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(280, 20)
    $label.Text = 'How many hours should this run?'
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10, 40)
    $textBox.Size = New-Object System.Drawing.Size(260, 20)
    $form.Controls.Add($textBox)

    $form.Topmost = $true

    $form.Add_Shown({ $textBox.Select() })
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $duration = $textBox.Text
        $seconds = $duration.toint32($null)
        $hours = ($seconds*3600)
        
        start-sleep -Seconds $hours
        Stop-Job -Name "keepAwake"
        $Main_Tool_Icon.Visible = $false
        Stop-Process $pid
    }
}


# ---------------------------------------------------------------------
# Action when after a click on the systray icon
# ---------------------------------------------------------------------
$Main_Tool_Icon.Add_Click({                    
    If ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
        $Main_Tool_Icon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).Invoke($Main_Tool_Icon,$null)
    }
})

 


 # When Start is clicked, start stayawake job and get its pid
$Menu_Start.add_Click({
    $Menu_Stop.Enabled = $true
    $Menu_Start.Enabled = $false
    $Menu_Timer.Enabled = $false
    Stop-Job -Name "keepAwake"
    Start-Job -ScriptBlock $keepAwakeScript -Name "keepAwake"
 })

 # When Timer is clicked, prompt for timeout, then start stayawake job and get its pid
 $Menu_Timer.add_Click({
    $Menu_Stop.Enabled = $true
    $Menu_Start.Enabled = $false
    $Menu_Timer.Enabled = $false
    Stop-Job -Name "keepAwake"
    
    #$duration = 10
    Start-Job -ScriptBlock $keepAwakeScript -Name "keepAwake"
    timerPrompt 
   
    $Menu_Stop.Enabled = $false
    $Menu_Start.Enabled = $true
    $Menu_Timer.Enabled = $true

 })

 # When Stop is clicked, kill stay awake job
$Menu_Stop.add_Click({
    $Menu_Stop.Enabled = $false
    $Menu_Start.Enabled = $true
    $Menu_Timer.Enabled = $true
    Stop-Job -Name "keepAwake"
 })


# When Exit is clicked, close everything and kill the PowerShell process
$Menu_Exit.add_Click({
    $Main_Tool_Icon.Visible = $false
    $window.Close()
    Stop-Job -Name "keepAwake"
    Stop-Process $pid
 })
 

 

# Make PowerShell Disappear
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

 

# Force garbage collection just to start slightly lower RAM usage.
[System.GC]::Collect()

 

# Create an application context for it to all run within.
# This helps with responsiveness, especially when clicking Exit.
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)