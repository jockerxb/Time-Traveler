using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
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
            var width = Math.Max(1, (int)Math.Ceiling(window.ActualWidth));
            var height = Math.Max(1, (int)Math.Ceiling(window.ActualHeight));
            var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
            bitmap.Render(window);
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(bitmap));
            using var stream = File.Create(fullPath);
            encoder.Save(stream);
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
}
