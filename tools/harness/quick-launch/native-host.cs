using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

public static class EinkHarnessNativeHost
{
    private const string RepoRoot = @"D:\EINK\Clock";
    private const int ProductionPort = 5175;
    private const int MaxMessageBytes = 65536;
    private const string AcceptanceEnvironment = "EINK_HARNESS_ACCEPTANCE_001";
    private const string ExtensionOrigin = "chrome-extension://bnkeegfocdpoljgaadmaciipdlfcmnkm/";
    private static readonly HashSet<string> AllowedActions = new HashSet<string>(StringComparer.Ordinal)
    {
        "START", "STATUS", "OPEN", "RESTART", "STOP"
    };
    private static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    private static int _port = ProductionPort;

    public static int Main(string[] args)
    {
        try
        {
            Configure(args);
            Dictionary<string, object> response = Dispatch(ReadMessage(Console.OpenStandardInput()));
            WriteMessage(Console.OpenStandardOutput(), response);
            return response.ContainsKey("ok") && Convert.ToBoolean(response["ok"]) ? 0 : 2;
        }
        catch (Exception ex)
        {
            try { WriteMessage(Console.OpenStandardOutput(), Result(false, "OFFLINE", "HOST_ERROR_" + SafeReason(ex.Message))); }
            catch { }
            return 1;
        }
    }

    private static void Configure(string[] args)
    {
        bool acceptance = string.Equals(Environment.GetEnvironmentVariable(AcceptanceEnvironment), "1", StringComparison.Ordinal);
        if (acceptance && args.Length == 2 && string.Equals(args[0], "--port", StringComparison.Ordinal))
        {
            int candidate;
            if (!int.TryParse(args[1], out candidate) || candidate < 1024 || candidate > 65535 || candidate == ProductionPort)
                throw new InvalidOperationException("ACCEPTANCE_PORT_BLOCKED");
            _port = candidate;
            WriteInvocationAudit("ACCEPTANCE", "", "", args.Length);
            return;
        }

        if (args.Length < 1 || args.Length > 2 || !string.Equals(args[0], ExtensionOrigin, StringComparison.Ordinal))
            throw new InvalidOperationException("HOST_ARGUMENTS_BLOCKED");

        string parentWindow = "";
        if (args.Length == 2)
        {
            const string prefix = "--parent-window=";
            if (!args[1].StartsWith(prefix, StringComparison.Ordinal))
                throw new InvalidOperationException("HOST_ARGUMENTS_BLOCKED");
            parentWindow = args[1].Substring(prefix.Length);
            ulong handle;
            if (parentWindow.Length == 0 || !ulong.TryParse(parentWindow, out handle))
                throw new InvalidOperationException("HOST_ARGUMENTS_BLOCKED");
        }
        WriteInvocationAudit("CHROME_NATIVE_MESSAGING", args[0], parentWindow, args.Length);
    }

    private static void WriteInvocationAudit(string mode, string origin, string parentWindow, int argumentCount)
    {
        try
        {
            string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "native-host-last-invocation.json");
            Dictionary<string, object> value = new Dictionary<string, object>
            {
                { "schema", "eink-harness-native-invocation-v1" },
                { "utc", DateTime.UtcNow.ToString("o") },
                { "mode", mode },
                { "argumentCount", argumentCount },
                { "origin", origin },
                { "parentWindow", parentWindow }
            };
            File.WriteAllText(path, Json.Serialize(value), new UTF8Encoding(false));
        }
        catch { }
    }

    private static Dictionary<string, object> Dispatch(Dictionary<string, object> request)
    {
        if (request == null || request.Count != 1 || !request.ContainsKey("action") || !(request["action"] is string))
            return Result(false, "OFFLINE", "INVALID_SCHEMA");
        string action = (string)request["action"];
        if (!AllowedActions.Contains(action)) return Result(false, "OFFLINE", "ACTION_NOT_ALLOWED");
        if (action == "STATUS") return HandleStatus();
        if (action == "START") return HandleStart();
        if (action == "OPEN") return HandleOpen();
        if (action == "RESTART") return HandleRestart();
        if (action == "STOP") return HandleStop();
        return Result(false, "OFFLINE", "ACTION_NOT_ALLOWED");
    }

    private static Dictionary<string, object> HandleStatus()
    {
        Dictionary<string, object> status = ReadStatus(2500);
        if (status == null) return Result(true, "OFFLINE", "HARNESS_OFFLINE");
        string reason;
        if (!VerifyIdentity(status, out reason)) return Result(false, "OFFLINE", reason);
        return OnlineResult(status, "HARNESS_ONLINE");
    }

    private static Dictionary<string, object> HandleStart()
    {
        Dictionary<string, object> status = ReadStatus(2500);
        if (status != null)
        {
            string existingReason;
            if (!VerifyIdentity(status, out existingReason)) return Result(false, "OFFLINE", existingReason);
            Dictionary<string, object> duplicate = OnlineResult(status, "ALREADY_RUNNING");
            duplicate["duplicatePrevented"] = true;
            return duplicate;
        }

        string launcher = Path.Combine(RepoRoot, @"scripts\eink-control-center.ps1");
        if (!File.Exists(launcher)) return Result(false, "OFFLINE", "LAUNCHER_MISSING");
        string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
        string logRoot = Path.Combine(Path.GetTempPath(), "EINKHarnessNative");
        Directory.CreateDirectory(logRoot);
        string logKey = "launcher-" + _port + "-" + Guid.NewGuid().ToString("N");
        string stdoutPath = Path.Combine(logRoot, logKey + ".stdout.log");
        string stderrPath = Path.Combine(logRoot, logKey + ".stderr.log");
        string command = "\"\"" + powershell + "\" -NoProfile -ExecutionPolicy Bypass -File \"" + launcher +
            "\" -Port " + _port + " -NoBrowser 1>\"" + stdoutPath + "\" 2>\"" + stderrPath + "\"\"";
        ProcessStartInfo info = new ProcessStartInfo
        {
            FileName = Environment.GetEnvironmentVariable("ComSpec"),
            Arguments = "/d /s /c " + command,
            WorkingDirectory = RepoRoot,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        using (Process launcherProcess = Process.Start(info))
        {
            if (!launcherProcess.WaitForExit(45000))
            {
                CleanupExactLauncher(launcherProcess);
                CleanupTrackedUnhealthyServer();
                return Result(false, "OFFLINE", "START_TIMEOUT");
            }
            string stdout = ReadSharedText(stdoutPath);
            string stderr = ReadSharedText(stderrPath);
            TryDelete(stdoutPath);
            TryDelete(stderrPath);
            if (launcherProcess.ExitCode != 0)
                return Result(false, "OFFLINE", "START_FAILED_" + SafeReason(LastUsefulLine(stdout, stderr)));
        }

        status = WaitForOnline(35000, -1);
        if (status == null) return Result(false, "OFFLINE", "START_HEALTH_TIMEOUT");
        string reason;
        if (!VerifyIdentity(status, out reason)) return Result(false, "OFFLINE", reason);
        return OnlineResult(status, "STARTED");
    }

    private static Dictionary<string, object> HandleOpen()
    {
        Dictionary<string, object> status = ReadStatus(2500);
        if (status == null) return Result(false, "OFFLINE", "HARNESS_OFFLINE");
        string reason;
        if (!VerifyIdentity(status, out reason)) return Result(false, "OFFLINE", reason);
        Dictionary<string, object> result = OnlineResult(status, "OPEN_APPROVED");
        result["open"] = true;
        return result;
    }

    private static Dictionary<string, object> HandleRestart()
    {
        Dictionary<string, object> status = ReadStatus(2500);
        if (status == null) return HandleStart();
        string reason;
        if (!VerifyIdentity(status, out reason)) return Result(false, "OFFLINE", reason);
        int oldPid = GetInt(GetDictionary(status, "lifecycle"), "pid");
        Process oldProcess = Process.GetProcessById(oldPid);
        if (!PostLifecycle(status, "restart", out reason)) return Result(false, "OFFLINE", reason);
        if (!oldProcess.WaitForExit(35000)) return Result(false, "OFFLINE", "RESTART_OLD_EXIT_TIMEOUT");
        Dictionary<string, object> replacement = WaitForOnline(40000, oldPid);
        if (replacement == null) return Result(false, "OFFLINE", "RESTART_HEALTH_TIMEOUT");
        if (!VerifyIdentity(replacement, out reason)) return Result(false, "OFFLINE", reason);
        return OnlineResult(replacement, "RESTARTED");
    }

    private static Dictionary<string, object> HandleStop()
    {
        Dictionary<string, object> status = ReadStatus(2500);
        if (status == null) return Result(true, "OFFLINE", "ALREADY_STOPPED");
        string reason;
        if (!VerifyIdentity(status, out reason)) return Result(false, "ONLINE", reason);
        int pid = GetInt(GetDictionary(status, "lifecycle"), "pid");
        Process exact = Process.GetProcessById(pid);
        if (!PostLifecycle(status, "stop", out reason)) return Result(false, "ONLINE", reason);
        if (!exact.WaitForExit(35000)) return Result(false, "ONLINE", "STOP_EXACT_PID_TIMEOUT");
        DateTime deadline = DateTime.UtcNow.AddSeconds(10);
        while (DateTime.UtcNow < deadline)
        {
            if (ReadStatus(1200) == null) return Result(true, "OFFLINE", "STOPPED");
            Thread.Sleep(100);
        }
        return Result(false, "ONLINE", "STOP_HEALTH_TIMEOUT");
    }

    private static bool PostLifecycle(Dictionary<string, object> status, string action, out string reason)
    {
        reason = "";
        string token = GetString(status, "sessionToken");
        if (string.IsNullOrEmpty(token)) { reason = "SESSION_TOKEN_MISSING"; return false; }
        try
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(HarnessUrl + "api/lifecycle/" + action);
            request.Method = "POST";
            request.ContentType = "application/json; charset=utf-8";
            request.Headers.Add("X-Eink-Control-Token", token);
            request.Timeout = 5000;
            request.ReadWriteTimeout = 5000;
            byte[] body = Encoding.UTF8.GetBytes("{}");
            request.ContentLength = body.Length;
            using (Stream stream = request.GetRequestStream()) stream.Write(body, 0, body.Length);
            using (HttpWebResponse response = (HttpWebResponse)request.GetResponse()) return response.StatusCode == HttpStatusCode.OK;
        }
        catch (Exception ex)
        {
            reason = "LIFECYCLE_" + action.ToUpperInvariant() + "_FAILED_" + SafeReason(ex.Message);
            return false;
        }
    }

    private static Dictionary<string, object> WaitForOnline(int timeoutMs, int excludedPid)
    {
        DateTime deadline = DateTime.UtcNow.AddMilliseconds(timeoutMs);
        int delay = 75;
        while (DateTime.UtcNow < deadline)
        {
            Dictionary<string, object> status = ReadStatus(1500);
            if (status != null && GetInt(GetDictionary(status, "lifecycle"), "pid") != excludedPid) return status;
            Thread.Sleep(delay);
            delay = Math.Min(500, delay * 2);
        }
        return null;
    }

    private static Dictionary<string, object> ReadStatus(int timeoutMs)
    {
        try
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(HarnessUrl + "api/status");
            request.Method = "GET";
            request.Timeout = timeoutMs;
            request.ReadWriteTimeout = timeoutMs;
            using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
            using (StreamReader reader = new StreamReader(response.GetResponseStream(), Encoding.UTF8))
            {
                Dictionary<string, object> status = Json.Deserialize<Dictionary<string, object>>(reader.ReadToEnd());
                return GetString(status, "hubId") == "harness-control-center" ? status : null;
            }
        }
        catch { return null; }
    }

    private static bool VerifyIdentity(Dictionary<string, object> status, out string reason)
    {
        reason = "UNTRUSTED_SERVER_IDENTITY";
        Dictionary<string, object> lifecycle = GetDictionary(status, "lifecycle");
        if (lifecycle == null) return false;
        int pid = GetInt(lifecycle, "pid");
        long ticks = GetLong(lifecycle, "processStartTicks");
        string lockPath = Path.Combine(RepoRoot, @"_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME\server-" + _port + ".json");
        if (!File.Exists(lockPath)) return false;
        Dictionary<string, object> lockData;
        try { lockData = Json.Deserialize<Dictionary<string, object>>(File.ReadAllText(lockPath, Encoding.UTF8)); }
        catch { return false; }
        if (GetString(lockData, "schema") != "eink-control-center-server-lock-v1" ||
            GetInt(lockData, "port") != _port || GetInt(lockData, "pid") != pid ||
            GetLong(lockData, "processStartTicks") != ticks ||
            !PathEquals(GetString(lockData, "repoRoot"), RepoRoot) ||
            !PathEquals(GetString(lockData, "scriptPath"), Path.Combine(RepoRoot, @"tools\harness\control-center\server.ps1"))) return false;
        try
        {
            Process process = Process.GetProcessById(pid);
            if (process.StartTime.ToUniversalTime().Ticks != ticks ||
                !PathEquals(process.MainModule.FileName, GetString(lockData, "executablePath")) ||
                process.MainWindowHandle != IntPtr.Zero) return false;
        }
        catch { return false; }
        reason = "";
        return true;
    }

    private static void CleanupExactLauncher(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill();
                process.WaitForExit(5000);
            }
        }
        catch { }
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); } catch { }
    }

    private static string ReadSharedText(string path)
    {
        if (!File.Exists(path)) return "";
        using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        using (StreamReader reader = new StreamReader(stream, Encoding.UTF8)) return reader.ReadToEnd();
    }

    private static void CleanupTrackedUnhealthyServer()
    {
        string path = Path.Combine(RepoRoot, @"_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME\server-" + _port + ".json");
        try
        {
            if (!File.Exists(path)) return;
            Dictionary<string, object> lockData = Json.Deserialize<Dictionary<string, object>>(File.ReadAllText(path, Encoding.UTF8));
            Process process = Process.GetProcessById(GetInt(lockData, "pid"));
            if (GetInt(lockData, "port") == _port && process.StartTime.ToUniversalTime().Ticks == GetLong(lockData, "processStartTicks") &&
                PathEquals(process.MainModule.FileName, GetString(lockData, "executablePath")) &&
                PathEquals(GetString(lockData, "scriptPath"), Path.Combine(RepoRoot, @"tools\harness\control-center\server.ps1")))
            {
                process.Kill();
                process.WaitForExit(5000);
            }
        }
        catch { }
    }

    private static Dictionary<string, object> OnlineResult(Dictionary<string, object> status, string reason)
    {
        Dictionary<string, object> result = Result(true, "ONLINE", reason);
        Dictionary<string, object> lifecycle = GetDictionary(status, "lifecycle");
        result["pid"] = GetInt(lifecycle, "pid");
        result["processStartTicks"] = GetLong(lifecycle, "processStartTicks");
        result["url"] = HarnessUrl;
        return result;
    }

    private static Dictionary<string, object> Result(bool ok, string state, string reason)
    {
        return new Dictionary<string, object> { { "ok", ok }, { "state", state }, { "reason", reason } };
    }

    private static Dictionary<string, object> ReadMessage(Stream input)
    {
        byte[] lengthBytes = ReadExact(input, 4);
        int length = BitConverter.ToInt32(lengthBytes, 0);
        if (length <= 0 || length > MaxMessageBytes) throw new InvalidDataException("MESSAGE_LENGTH_BLOCKED");
        return Json.Deserialize<Dictionary<string, object>>(Encoding.UTF8.GetString(ReadExact(input, length)));
    }

    private static void WriteMessage(Stream output, Dictionary<string, object> value)
    {
        byte[] body = Encoding.UTF8.GetBytes(Json.Serialize(value));
        byte[] length = BitConverter.GetBytes(body.Length);
        output.Write(length, 0, length.Length);
        output.Write(body, 0, body.Length);
        output.Flush();
    }

    private static byte[] ReadExact(Stream input, int count)
    {
        byte[] data = new byte[count];
        int offset = 0;
        while (offset < count)
        {
            int read = input.Read(data, offset, count - offset);
            if (read <= 0) throw new EndOfStreamException("NATIVE_MESSAGE_TRUNCATED");
            offset += read;
        }
        return data;
    }

    private static Dictionary<string, object> GetDictionary(Dictionary<string, object> value, string key)
    {
        object item;
        return value != null && value.TryGetValue(key, out item) ? item as Dictionary<string, object> : null;
    }

    private static string GetString(Dictionary<string, object> value, string key)
    {
        object item;
        return value != null && value.TryGetValue(key, out item) && item != null ? Convert.ToString(item) : "";
    }

    private static int GetInt(Dictionary<string, object> value, string key)
    {
        object item;
        return value != null && value.TryGetValue(key, out item) && item != null ? Convert.ToInt32(item) : 0;
    }

    private static long GetLong(Dictionary<string, object> value, string key)
    {
        object item;
        return value != null && value.TryGetValue(key, out item) && item != null ? Convert.ToInt64(item) : 0L;
    }

    private static bool PathEquals(string left, string right)
    {
        try { return string.Equals(Path.GetFullPath(left), Path.GetFullPath(right), StringComparison.OrdinalIgnoreCase); }
        catch { return false; }
    }

    private static string LastUsefulLine(string stdout, string stderr)
    {
        string text = string.IsNullOrWhiteSpace(stderr) ? stdout : stderr;
        string[] lines = (text ?? "").Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
        return lines.Length == 0 ? "NO_OUTPUT" : lines[lines.Length - 1];
    }

    private static string SafeReason(string value)
    {
        if (string.IsNullOrWhiteSpace(value)) return "UNKNOWN";
        StringBuilder builder = new StringBuilder();
        foreach (char c in value.ToUpperInvariant())
        {
            if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_') builder.Append(c);
            else if (builder.Length == 0 || builder[builder.Length - 1] != '_') builder.Append('_');
            if (builder.Length >= 120) break;
        }
        return builder.ToString().Trim('_');
    }

    private static string HarnessUrl { get { return "http://127.0.0.1:" + _port + "/"; } }
}
