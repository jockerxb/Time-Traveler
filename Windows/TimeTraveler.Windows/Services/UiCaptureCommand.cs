using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Controls;
using System.Text.Json;
using TimeTraveler.Windows.Models;

namespace TimeTraveler.Windows.Services;

public static class UiCaptureCommand
{
    public static int Run(string outputPath, AppLanguage language)
    {
        try
        {
            var fullPath = Path.GetFullPath(outputPath);
            Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
            var window = new MainWindow(language, captureMode: true);
            window.Show();
            window.UpdateLayout();
            window.Dispatcher.Invoke(() => { }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
            Capture(window, fullPath);

            var zones = TimeZoneItem.Load();
            var picker = new TimeZonePickerWindow(zones, null, language) { Owner = window };
            picker.Loaded += (_, _) => picker.Dispatcher.BeginInvoke(new Action(() =>
            {
                picker.SearchBox.Text = language == AppLanguage.Chinese ? "北京" : "Beijing";
                picker.UpdateLayout();
                if (picker.ZoneList.Items.Count != 1) throw new InvalidOperationException("Picker city search failed.");
                picker.ZoneList.SelectedIndex = 0;
                Capture(picker, Path.ChangeExtension(fullPath, "picker.png"));
                picker.SelectButton.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            }));
            if (picker.ShowDialog() != true || picker.SelectedTimeZone?.Id != "China Standard Time")
                throw new InvalidOperationException("Picker selection did not return the selected time zone.");

            var cancelled = new TimeZonePickerWindow(zones, null, language) { Owner = window };
            cancelled.Loaded += (_, _) => cancelled.Dispatcher.BeginInvoke(new Action(() =>
            {
                cancelled.SearchBox.Text = "nonexistent-zone-782019";
                if (cancelled.ZoneList.Items.Count != 0 || cancelled.NoResultsText.Visibility != Visibility.Visible)
                    throw new InvalidOperationException("Picker empty state failed.");
                cancelled.CancelButton.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            }));
            if (cancelled.ShowDialog() != false || cancelled.SelectedTimeZone is not null)
                throw new InvalidOperationException("Cancelling the picker changed its selection.");

            File.WriteAllText(Path.ChangeExtension(fullPath, "checks.json"), JsonSerializer.Serialize(new
            {
                success = true,
                language = language.ToString(),
                mainWindowRendered = true,
                pickerSearchAndSelection = true,
                pickerEmptyStateAndCancel = true
            }));
            window.Close();
            return 0;
        }
        catch (Exception error)
        {
            try
            {
                var errorPath = Path.GetFullPath(outputPath) + ".error.txt";
                Directory.CreateDirectory(Path.GetDirectoryName(errorPath)!);
                File.WriteAllText(errorPath, error.ToString());
            }
            catch
            {
                // Preserve the original capture failure as the exit status.
            }
            Console.Error.WriteLine(error);
            return 1;
        }
    }

    private static void Capture(Window window, string path)
    {
        window.UpdateLayout();
        var width = Math.Max(1, (int)Math.Ceiling(window.ActualWidth));
        var height = Math.Max(1, (int)Math.Ceiling(window.ActualHeight));
        var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        var background = new DrawingVisual();
        using (var drawing = background.RenderOpen())
            drawing.DrawRectangle(window.Background, null, new Rect(0, 0, width, height));
        bitmap.Render(background);
        bitmap.Render(window);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(path);
        encoder.Save(stream);
    }
}
