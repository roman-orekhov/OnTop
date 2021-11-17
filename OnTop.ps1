# C:\Windows\System32\cmd.exe /k
# C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File D:\Development\Powershell\OnTop\OnTop.ps1 "-Excavator*"
# C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File D:\Development\Powershell\OnTop\OnTop.ps1 "Excavator*"

Add-Type -AssemblyName System.Drawing, System.Windows.Forms, System.Collections

if (-not ("Window" -as [type])) {

    $Native = Add-Type -Debug:$False -MemberDefinition @'
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X,int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern IntPtr GetTopWindow(IntPtr hWnd);
    [DllImport("kernel32.dll")]
    public static extern uint GetLastError();
'@ -Name "NativeFunctions" -Namespace NativeFunctions -PassThru
    

    Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public struct RECT
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

public class WinStruct
{
  public string WinTitle {get; set; }
  public int WinHwnd { get; set; }
}

class GetWindowsHelper
{
   private delegate bool CallBackPtr(int hwnd, int lParam);
   private static CallBackPtr callBackPtr = Callback;
   private static List<WinStruct> _WinStructList = new List<WinStruct>();

   [DllImport("user32.dll")]
   [return: MarshalAs(UnmanagedType.Bool)]
   private static extern bool EnumWindows(CallBackPtr lpEnumFunc, IntPtr lParam);
   [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
   public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

   private static bool Callback(int hWnd, int lparam)
   {
       StringBuilder sb = new StringBuilder(256);
       int res = GetWindowText((IntPtr)hWnd, sb, 256);
      _WinStructList.Add(new WinStruct { WinHwnd = hWnd, WinTitle = sb.ToString() });
       return true;
   }   

   public static List<WinStruct> GetWindows()
   {
      _WinStructList = new List<WinStruct>();
      EnumWindows(callBackPtr, IntPtr.Zero);
      return _WinStructList;
   }
}

public class Window
{
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
     
    public static List<WinStruct> GetWindows()
    {
        return GetWindowsHelper.GetWindows();
    }
}
"@
}

function raise {
    param (
        [parameter(position = 0)]
        [int]$i
    )
    Write-Error "$i ==> $((New-Object System.ComponentModel.Win32Exception([int]$Native::GetLastError())).Message)"
}

########################
# $z_first = $Native::GetWindow($Native::GetForegroundWindow(), 3)
# if ($z_first -eq 0) {
#     Write-Warning "no foreground window"
#     $z_first = $Native::GetTopWindow(0)
# }
# windows get atop of current window, but without topmost style, unlike if done like below:
$z_first = $Native::GetTopWindow(0)
$windows = [Window]::GetWindows()
########################

$first = $z_first

ForEach ($arg in $args) {
    if ($arg.StartsWith("-")) {
        $first = -2
        $arg = $arg.Remove(0, 1)
    } elseif ($arg.StartsWith("+")) {
        $first = $z_first
        $arg = $arg.Remove(0, 1)
    }
    $wnds = @($windows | Where-Object { $_.WinTitle -like "$arg" })

    if ($wnds.Count -eq 0) {
        Write-Error "'$arg' windows not found"
    }

    foreach ($w in $wnds) {
        # $w.WinTitle
        $r = New-Object RECT
        if (-not [Window]::GetWindowRect($w.WinHwnd, [ref]$r)) {
            Write-Error "'$($w.WinTitle)' can't get window rect"
            continue
        }
    
        if ($r.Right -lt 0 -and $r.Bottom -lt 0) {
            # $r | format-table
            Write-Warning "Restoring '$($w.WinTitle)' window"
            if (-not $Native::ShowWindow($w.WinHwnd, 9)) {
                raise 1
            }
        }
        if (-not $Native::SetWindowPos($w.WinHwnd, $first, 0, 0, 0, 0, 0x73)) {
            raise 2
        }
    }
}

#"Excavator*"
