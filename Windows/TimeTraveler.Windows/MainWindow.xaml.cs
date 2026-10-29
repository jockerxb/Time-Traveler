using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using TimeTraveler.Windows.Models;
using TimeTraveler.Windows.Services;

namespace TimeTraveler.Windows;

public partial class MainWindow : Window
{
    private readonly SettingsService _settingsService = new();
    private readonly AppDiscoveryService _discovery = new();
    private readonly HybridLauncher _launcher = new();
    private readonly ObservableCollection<AppTile> _tiles = [];
    private UserSettings _settings;
    private Localizer _text;
    private IReadOnlyList<TimeZoneItem> _zones = [];
    private TimeZoneItem? _selectedZone;
    private AppDefinition? _pendingApp;
    private bool _busy;
    private readonly DispatcherTimer _clock = new() { Interval = TimeSpan.FromSeconds(15) };

    public MainWindow(AppLanguage? languageOverride = null, bool captureMode = false)
    {
        InitializeComponent();
        _settings = captureMode ? new UserSettings() : _settingsService.Load();
        if (languageOverride is not null) _settings.Language = languageOverride.Value;
        if (captureMode) _settings.SelectedTimeZoneId = "China Standard Time";
        _text = new Localizer(_settings.Language);
        _zones = TimeZoneItem.Load();
        _selectedZone = _zones.FirstOrDefault(zone => zone.Id == _settings.SelectedTimeZoneId);
        AppsItemsControl.ItemsSource = _tiles;
        RefreshAll(captureMode);
        _clock.Tick += (_, _) => UpdateTimeZoneCard();
        _clock.Start();
        Closed += (_, _) => _clock.Stop();
    }

    private void RefreshAll(bool captureMode = false)
    {
        _text = new Localizer(_settings.Language);
        SubtitleText.Text = _text.Subtitle;
        LanguageButton.ToolTip = _text.SwitchLanguage;
        GitHubButton.ToolTip = _text.OpenGitHub;
        ClickToLaunchText.Text = _text.ClickToLaunch;
        ClearTimeZoneMenuItem.Header = _text.ClearTimeZone;
        ClearTimeZoneMenuItem.IsEnabled = _selectedZone is not null;
        UpdateTimeZoneCard();
        RefreshAppTiles(captureMode);
        SetStatus(_text.WindowsHint, false);
    }

    private void RefreshAppTiles(bool captureMode = false)
    {
        _tiles.Clear();
        foreach (var app in AppCatalog.All)
        {
            var target = captureMode ? null : _discovery.Find(app);
            _tiles.Add(new AppTile(app, target, _settings.Language, _text, IconService.Load(target), captureMode));
        }
    }

    private void UpdateTimeZoneCard()
    {
        if (_selectedZone is null)
        {
            TimeZoneTitleText.Text = _text.ChooseTimeZone;
            TimeZoneDetailText.Text = _text.EmptyTimeZone;
            return;
        }
        var now = DateTimeOffset.Now;
        TimeZoneTitleText.Text = _selectedZone.Name(_settings.Language);
        TimeZoneDetailText.Text = $"{_selectedZone.OffsetText(now)}  ·  {_selectedZone.DayAndTime(_settings.Language, now)}";
    }

    private void LanguageButton_Click(object sender, RoutedEventArgs e)
    {
        var menu = new ContextMenu();
        menu.Items.Add(LanguageItem("中文", AppLanguage.Chinese));
        menu.Items.Add(LanguageItem("English", AppLanguage.English));
        menu.PlacementTarget = LanguageButton;
        menu.IsOpen = true;
    }

    private MenuItem LanguageItem(string title, AppLanguage language)
    {
        var item = new MenuItem { Header = (_settings.Language == language ? "✓  " : "    ") + title, Tag = language };
        item.Click += (_, _) =>
        {
            _settings.Language = (AppLanguage)item.Tag;
            SaveSettings();
            RefreshAll();
        };
        return item;
    }

    private void GitHubButton_Click(object sender, RoutedEventArgs e) =>
        Process.Start(new ProcessStartInfo("https://github.com/jockerxb/Time-Traveler") { UseShellExecute = true });

    private void TimeZoneCard_LeftClick(object sender, MouseButtonEventArgs e) => OpenPicker();

    private void TimeZoneCard_RightClick(object sender, MouseButtonEventArgs e)
    {
        if (_selectedZone is not null) TimeZoneCard.ContextMenu.IsOpen = true;
        e.Handled = true;
    }

    private void ClearTimeZoneMenuItem_Click(object sender, RoutedEventArgs e)
    {
        _selectedZone = null;
        _settings.SelectedTimeZoneId = null;
        SaveSettings();
        UpdateTimeZoneCard();
        ClearTimeZoneMenuItem.IsEnabled = false;
    }

    private void OpenPicker()
    {
        if (_busy) return;
        var picker = new TimeZonePickerWindow(_zones, _selectedZone, _settings.Language) { Owner = this };
        if (picker.ShowDialog() != true || picker.SelectedTimeZone is null)
        {
            _pendingApp = null;
            return;
        }
        _selectedZone = picker.SelectedTimeZone;
        _settings.SelectedTimeZoneId = _selectedZone.Id;
        SaveSettings();
        UpdateTimeZoneCard();
        ClearTimeZoneMenuItem.IsEnabled = true;
        if (_pendingApp is not null)
        {
            var app = _pendingApp;
            _pendingApp = null;
            _ = LaunchAppAsync(app);
        }
    }

    private async void AppButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: AppDefinition app }) await LaunchAppAsync(app);
    }

    private async Task LaunchAppAsync(AppDefinition app)
    {
        if (_busy) return;
        var target = _discovery.Find(app);
        var name = app.DisplayName(_settings.Language);
        if (target is null)
        {
            MessageBox.Show(this, _text.NotInstalledBody(name), _text.NotInstalledTitle(name), MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        if (_selectedZone is null)
        {
            _pendingApp = app;
            OpenPicker();
            return;
        }
        SetBusy(app.Id, true);
        try
        {
            if (_launcher.IsRunning(app))
            {
                var answer = MessageBox.Show(this, _text.RestartBody, _text.RestartTitle(name), MessageBoxButton.OKCancel, MessageBoxImage.Warning);
                if (answer != MessageBoxResult.OK) return;
                if (!await _launcher.RequestQuitAsync(app, TimeSpan.FromSeconds(15)))
                {
                    MessageBox.Show(this, _text.AppDidNotQuit(name), _text.LaunchFailed, MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
            }
            SetStatus(_text.Launching(name), false);
            await _launcher.LaunchAsync(app, target, _selectedZone);
            SetStatus(_text.LaunchSucceeded(name), false);
        }
        catch (UnauthorizedAccessException)
        {
            SetStatus(_text.PermissionDenied, true);
        }
        catch (Exception error)
        {
            var message = error.Message.StartsWith("RESTORE_FAILED|", StringComparison.Ordinal)
                ? _text.RestoreFailed(error.Message.Split('|').ElementAtOrDefault(1) ?? "Windows")
                : error.Message;
            SetStatus(message, true);
            MessageBox.Show(this, message, _text.LaunchFailed, MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            SetBusy(app.Id, false);
        }
    }

    private void SetBusy(string appId, bool busy)
    {
        _busy = busy;
        LanguageButton.IsEnabled = !busy;
        TimeZoneCard.IsEnabled = !busy;
        foreach (var tile in _tiles) tile.SetBusy(tile.Definition.Id == appId && busy, busy);
    }

    private void SetStatus(string message, bool error)
    {
        StatusText.Text = message;
        StatusText.Foreground = error ? Brushes.Firebrick : (Brush)FindResource("SecondaryText");
        StatusIconText.Text = error ? "⚠" : "ⓘ";
        StatusIconText.Foreground = error ? Brushes.Firebrick : (Brush)FindResource("Accent");
    }

    private void SaveSettings() => _settingsService.Save(_settings);
}

public sealed class AppTile : System.ComponentModel.INotifyPropertyChanged
{
    private bool _busy;
    private bool _disabledByBusy;
    public AppDefinition Definition { get; }
    public string DisplayName { get; }
    public string Initial { get; }
    public string InstallState { get; }
    public ImageSource? Icon { get; }
    public Brush AccentBrush { get; }
    public Visibility IconVisibility => Icon is null ? Visibility.Collapsed : Visibility.Visible;
    public Visibility FallbackVisibility => Icon is null ? Visibility.Visible : Visibility.Collapsed;
    public Visibility BusyVisibility => _busy ? Visibility.Visible : Visibility.Collapsed;
    public bool IsEnabled => !_disabledByBusy;
    public event System.ComponentModel.PropertyChangedEventHandler? PropertyChanged;

    public AppTile(AppDefinition definition, LaunchTarget? target, AppLanguage language, Localizer text, ImageSource? icon, bool captureMode)
    {
        Definition = definition;
        DisplayName = definition.DisplayName(language);
        Initial = definition.EnglishName[..1];
        Icon = icon;
        AccentBrush = (Brush)new BrushConverter().ConvertFromString(definition.AccentHex)!;
        InstallState = target is null && !captureMode ? text.NotInstalled : "";
    }

    public void SetBusy(bool busy, bool anyBusy)
    {
        _busy = busy;
        _disabledByBusy = anyBusy;
        PropertyChanged?.Invoke(this, new(nameof(BusyVisibility)));
        PropertyChanged?.Invoke(this, new(nameof(IsEnabled)));
    }
}
