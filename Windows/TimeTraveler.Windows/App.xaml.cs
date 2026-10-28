using System.Windows;
using TimeTraveler.Windows.Services;

namespace TimeTraveler.Windows;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        if (e.Args.Length > 0 && e.Args[0] == "--elevated-helper")
        {
            var exitCode = ElevatedTimeZoneHelper.Run(e.Args.Skip(1).ToArray());
            Environment.Exit(exitCode);
            return;
        }

        if (e.Args.Length > 0 && e.Args[0] == "--integration-test")
        {
            var exitCode = IntegrationTestCommand.RunAsync(e.Args.Skip(1).ToArray()).GetAwaiter().GetResult();
            Environment.Exit(exitCode);
            return;
        }

        if (e.Args.Length > 1 && e.Args[0] == "--capture-ui")
        {
            var captureLanguage = e.Args.Contains("--english") ? AppLanguage.English : AppLanguage.Chinese;
            var exitCode = UiCaptureCommand.Run(e.Args[1], captureLanguage);
            Environment.Exit(exitCode);
            return;
        }

        var language = e.Args.Contains("--english") ? AppLanguage.English : (AppLanguage?)null;
        var window = new MainWindow(language);
        MainWindow = window;
        ShutdownMode = ShutdownMode.OnMainWindowClose;
        window.Show();
    }
}
