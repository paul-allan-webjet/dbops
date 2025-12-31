using System;
using System.Collections.Generic;
using System.Text;
using DbUp.Engine.Output;

namespace DBOps.Tests
{
    public class CaptureLogsLogger : IUpgradeLog
    {
        readonly StringBuilder logBuilder = new StringBuilder();
        public List<string> InfoMessages { get; } = new List<string>();
        public List<string> WarnMessages { get; } = new List<string>();
        public List<string> ErrorMessages { get; } = new List<string>();

        public string Log => logBuilder.ToString();

        public void LogTrace(string format, params object[] args)
        {
            var formattedMsg = string.Format(format, args);
            var value = "Trace:        " + formattedMsg;
            Console.WriteLine(value);
            logBuilder.AppendLine(value);
        }

        public void LogDebug(string format, params object[] args)
        {
            var formattedMsg = string.Format(format, args);
            var value = "Debug:        " + formattedMsg;
            Console.WriteLine(value);
            logBuilder.AppendLine(value);
        }

        public void LogInformation(string format, params object[] args)
        {
            var formattedMsg = string.Format(format, args);
            var value = "Info:         " + formattedMsg;
            Console.WriteLine(value);
            logBuilder.AppendLine(value);
            InfoMessages.Add(formattedMsg);
        }

        public void LogWarning(string format, params object[] args)
        {
            var formattedValue = string.Format(format, args);
            var value = "Warn:         " + formattedValue;
            Console.WriteLine(value);
            logBuilder.AppendLine(value);
            WarnMessages.Add(formattedValue);
        }

        public void LogError(string format, params object[] args)
        {
            var formattedMessage = string.Format(format, args);
            var value = "Error:        " + formattedMessage;
            Console.WriteLine(value);
            logBuilder.AppendLine(value);
            ErrorMessages.Add(formattedMessage);
        }

        public void LogError(Exception ex, string format, params object[] args)
        {
            var formattedMessage = string.Format(format, args);
            var value = $"Error:        {formattedMessage}\nException: {ex}";
            Console.WriteLine(value);
            logBuilder.AppendLine(value);
            ErrorMessages.Add(formattedMessage);
        }

        public void WriteDbOperation(string operation)
        {
            var value = "DB Operation: " + operation;
            Console.WriteLine(value);
            logBuilder.AppendLine(value);
        }
    }
}