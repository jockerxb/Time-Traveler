using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using TimeTraveler.Windows.Models;

namespace TimeTraveler.Windows.Services;

public static class IconService
{
    private const uint ShgfiIcon = 0x000000100;
    private const uint ShgfiLargeIcon = 0x000000000;

    public static ImageSource LoadBundled(string appId)
    {
        var icon = new BitmapImage(new Uri($"pack://application:,,,/TimeTraveler;component/Assets/AppIcons/{appId}.png"));
        icon.Freeze();
        return icon;
    }

    public static ImageSource? Load(LaunchTarget? target)
    {
        if (target is null || target.Kind == LaunchTargetKind.Uri || !File.Exists(target.Value)) return null;

        var info = new ShFileInfo();
        var result = SHGetFileInfo(target.Value, 0, ref info, (uint)Marshal.SizeOf<ShFileInfo>(), ShgfiIcon | ShgfiLargeIcon);
        if (result == IntPtr.Zero || info.IconHandle == IntPtr.Zero) return null;

        try
        {
            var source = Imaging.CreateBitmapSourceFromHIcon(info.IconHandle, Int32Rect.Empty, BitmapSizeOptions.FromWidthAndHeight(96, 96));
            source.Freeze();
            return source;
        }
        finally
        {
            DestroyIcon(info.IconHandle);
        }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct ShFileInfo
    {
        public IntPtr IconHandle;
        public int IconIndex;
        public uint Attributes;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string DisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)] public string TypeName;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr SHGetFileInfo(string path, uint fileAttributes, ref ShFileInfo info, uint infoSize, uint flags);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr iconHandle);
}
