using System.Windows;
using System.Windows.Controls;
using TimeTraveler.Windows.Models;
using TimeTraveler.Windows.Services;

namespace TimeTraveler.Windows;

public partial class TimeZonePickerWindow : Window
{
    private readonly IReadOnlyList<TimeZoneItem> _zones;
    private readonly AppLanguage _language;
    private readonly Localizer _text;
    public TimeZoneItem? SelectedTimeZone { get; private set; }

    public TimeZonePickerWindow(IReadOnlyList<TimeZoneItem> zones, TimeZoneItem? selected, AppLanguage language)
    {
        InitializeComponent();
        _zones = zones;
        _language = language;
        _text = new Localizer(language);
        Title = _text.ChooseTimeZone;
        TitleText.Text = _text.ChooseTimeZone;
        SubtitleText.Text = _text.PickerSubtitle;
        SearchBox.ToolTip = _text.SearchPlaceholder;
        NoResultsText.Text = _text.NoResults;
        CancelButton.Content = _text.Cancel;
        SelectButton.Content = _text.UseThisTimeZone;
        RefreshList("");
        if (selected is not null)
        {
            ZoneList.SelectedItem = ((IEnumerable<ZoneRow>)ZoneList.ItemsSource).FirstOrDefault(row => row.Item.Id == selected.Id);
            ZoneList.ScrollIntoView(ZoneList.SelectedItem);
        }
    }

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e) => RefreshList(SearchBox.Text);

    private void RefreshList(string query)
    {
        var rows = _zones.Where(zone => zone.Matches(query, _language))
            .Select(zone => new ZoneRow(zone, zone.Name(_language), zone.Id, zone.OffsetText(DateTimeOffset.Now)))
            .ToArray();
        ZoneList.ItemsSource = rows;
        NoResultsText.Visibility = rows.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void ZoneList_SelectionChanged(object sender, SelectionChangedEventArgs e) => SelectButton.IsEnabled = ZoneList.SelectedItem is ZoneRow;

    private void SelectButton_Click(object sender, RoutedEventArgs e)
    {
        if (ZoneList.SelectedItem is not ZoneRow row) return;
        SelectedTimeZone = row.Item;
        DialogResult = true;
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e) => DialogResult = false;

    public sealed record ZoneRow(TimeZoneItem Item, string Name, string Id, string Offset);
}
