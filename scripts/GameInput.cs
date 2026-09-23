using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

// Test-session input only. Never injected into the game or shipped in thprac.
public static class ThpracGameInput
{
    [StructLayout(LayoutKind.Sequential)]
    private struct Keyboard { public ushort Vk, Scan; public uint Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)]
    private struct Mouse { public int X, Y; public uint Data, Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Explicit)]
    private struct Payload {
        [FieldOffset(0)] public Keyboard Key;
        [FieldOffset(0)] public Mouse Mouse;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct Input { public uint Type; public Payload Data; }
    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);

    private static Input Make(ushort scan, bool up) {
        return new Input { Type = 1, Data = new Payload { Key = new Keyboard {
            Scan = (ushort)(scan & 0xff), Flags = 8u | (scan > 0xff ? 1u : 0u) | (up ? 2u : 0u)
        } } };
    }
    private static bool IsForeground(Process game) {
        uint pid;
        GetWindowThreadProcessId(GetForegroundWindow(), out pid);
        return !game.HasExited && pid == game.Id;
    }
    public static void Press(Process game, ushort[] scans, int milliseconds) {
        if (milliseconds < 30 || milliseconds > 2000 || scans.Length == 0 || scans.Length > 4)
            throw new ArgumentException("Use 1-4 keys and a 30-2000 ms hold.");
        game.Refresh();
        if (game.HasExited || game.MainWindowHandle == IntPtr.Zero)
            throw new InvalidOperationException("The owned game has no live main window.");
        SetForegroundWindow(game.MainWindowHandle);
        Thread.Sleep(150);
        if (!IsForeground(game)) throw new InvalidOperationException("Game is not foreground; no input sent.");
        var down = new Input[scans.Length];
        var up = new Input[scans.Length];
        for (int i = 0; i < scans.Length; i++) {
            down[i] = Make(scans[i], false);
            up[scans.Length - 1 - i] = Make(scans[i], true);
        }
        try {
            if (SendInput((uint)down.Length, down, Marshal.SizeOf(typeof(Input))) != down.Length)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Key-down injection incomplete.");
            var timer = Stopwatch.StartNew();
            while (timer.ElapsedMilliseconds < milliseconds) {
                if (!IsForeground(game)) throw new InvalidOperationException("Game lost focus; releasing keys.");
                Thread.Sleep(10);
            }
        } finally {
            if (SendInput((uint)up.Length, up, Marshal.SizeOf(typeof(Input))) != up.Length)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Key release incomplete.");
        }
        Thread.Sleep(120); // Distinct presses must span an observed released frame.
    }
}
