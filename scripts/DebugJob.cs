using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

// A private job owns only processes launched by this session. Suspend the loader
// until assignment so even an immediately exiting bootstrap cannot escape tracking.
public sealed class ThpracDebugJob : IDisposable
{
    private IntPtr job;
    public Process Root { get; private set; }

    [StructLayout(LayoutKind.Sequential)]
    private struct BasicLimits {
        public long ProcessTime, JobTime;
        public uint Flags;
        public UIntPtr MinWorkingSet, MaxWorkingSet;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct ExtendedLimits {
        public BasicLimits Basic;
        public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes;
        public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct StartupInfo {
        public int Size;
        public string Reserved, Desktop, Title;
        public int X, Y, XSize, YSize, XChars, YChars, Fill, Flags;
        public short ShowWindow, ReservedSize;
        public IntPtr ReservedBytes, Input, Output, Error;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInfo { public IntPtr Process, Thread; public uint Pid, Tid; }
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetInformationJobObject(IntPtr job, int type, ref ExtendedLimits info, int size);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool QueryInformationJobObject(IntPtr job, int type, IntPtr info, int size, out int returned);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool IsProcessInJob(IntPtr process, IntPtr job, out bool result);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateProcess(string application, StringBuilder command, IntPtr pa, IntPtr ta,
        bool inherit, uint flags, IntPtr environment, string directory, ref StartupInfo startup, out ProcessInfo info);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll")]
    private static extern bool TerminateProcess(IntPtr process, uint code);
    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);

    public static string Quote(string value) {
        var text = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in value) {
            if (c == '\\') { slashes++; continue; }
            text.Append('\\', c == '"' ? slashes * 2 + 1 : slashes);
            text.Append(c);
            slashes = 0;
        }
        text.Append('\\', slashes * 2);
        return text.Append('"').ToString();
    }

    public ThpracDebugJob(string executable, string[] args, string directory) {
        job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero) throw new Win32Exception();
        var info = new ProcessInfo();
        try {
            var limits = new ExtendedLimits();
            limits.Basic.Flags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            if (!SetInformationJobObject(job, 9, ref limits, Marshal.SizeOf(limits))) throw new Win32Exception();
            var command = new StringBuilder(Quote(executable));
            foreach (string arg in args) command.Append(' ').Append(Quote(arg));
            var startup = new StartupInfo { Size = Marshal.SizeOf(typeof(StartupInfo)) };
            if (!CreateProcess(executable, command, IntPtr.Zero, IntPtr.Zero, false, 4, IntPtr.Zero,
                directory, ref startup, out info)) throw new Win32Exception(); // CREATE_SUSPENDED
            if (!AssignProcessToJobObject(job, info.Process)) throw new Win32Exception();
            Root = Process.GetProcessById((int)info.Pid);
            var handle = Root.Handle; // Retain identity and exit status before resuming.
            if (ResumeThread(info.Thread) == uint.MaxValue) throw new Win32Exception();
        } catch {
            if (info.Process != IntPtr.Zero) TerminateProcess(info.Process, 1);
            Dispose();
            throw;
        } finally {
            if (info.Thread != IntPtr.Zero) CloseHandle(info.Thread);
            if (info.Process != IntPtr.Zero) CloseHandle(info.Process);
        }
    }

    public Process[] Processes() {
        for (int capacity = 32; capacity <= 4096; capacity *= 2) {
            int size = 8 + capacity * IntPtr.Size;
            IntPtr buffer = Marshal.AllocHGlobal(size);
            try {
                int returned;
                if (!QueryInformationJobObject(job, 3, buffer, size, out returned)) {
                    int error = Marshal.GetLastWin32Error();
                    if (error == 234) continue;
                    throw new Win32Exception(error);
                }
                var result = new System.Collections.Generic.List<Process>();
                int count = Marshal.ReadInt32(buffer, 4);
                for (int i = 0; i < count; i++) {
                    Process process = null;
                    try {
                        int pid = (int)Marshal.ReadIntPtr(buffer, 8 + i * IntPtr.Size).ToInt64();
                        process = Process.GetProcessById(pid);
                        bool member;
                        if (IsProcessInJob(process.Handle, job, out member) && member && !process.HasExited) {
                            result.Add(process);
                            process = null;
                        }
                    } catch (ArgumentException) { }
                    catch (InvalidOperationException) { }
                    finally { if (process != null) process.Dispose(); }
                }
                return result.ToArray();
            } finally { Marshal.FreeHGlobal(buffer); }
        }
        throw new InvalidOperationException("Session job process list is too large.");
    }

    public void Dispose() {
        if (job != IntPtr.Zero) { CloseHandle(job); job = IntPtr.Zero; }
        if (Root != null) { Root.Dispose(); Root = null; }
    }
}
