# Weather Module

## Current version behavior

Weather is based on Open-Meteo.

Bar:
- compact icon + temperature;
- centered near Clock;
- no strong permanent pill;
- tooltip shows active city;
- scroll cycles saved cities.

Popup:
- city selector at top;
- saved city list;
- active city checkmark;
- remove saved city;
- `+ Adicionar cidade`;
- city search;
- current conditions;
- feels-like;
- humidity;
- wind;
- multi-day forecast.

The city search field uses `components/SearchField.qml`; geocoding, result
selection, and the explicit search action remain owned by the weather card.
Weather and saved-city status data use `CommandJson.result.data`; the city
search action uses the same normalizer and shows helper errors in the search
results area.

## Multi-city state

Persistent file:

`~/.local/state/quickshell/weather.json`

Example:

```json
{
  "selected": "some-city-id",
  "cities": [
    {
      "id": "some-city-id",
      "name": "Cidade Exemplo",
      "region": "Região Exemplo",
      "country": "Brasil",
      "latitude": 0.0,
      "longitude": 0.0
    }
  ]
}
```

## Scripts

### `scripts/weather-cities.py`

Responsibilities:
- `list`
- `search`
- `add`
- `select`
- `remove`
- `cycle`

Search uses Open-Meteo geocoding.

### `scripts/weather-fetch.py`

Responsibilities:
- resolve selected city;
- fallback to automatic network-derived location;
- query Open-Meteo;
- transform output;
- cache results;
- expose JSON to QML.

## Important cache rule

Do not show cached weather from one city after the user switches to another.

v0.19.1 explicitly checks selected city id against cached city id.

## Automatic location

Automatic mode is retained as a fallback.

Do not assume automatic geolocation is precise.

## UX rules

Bar stays compact.
City names belong in tooltip/popup, not permanently in the bar.

When the weather helper returns a cached forecast with a refresh error, keep the
forecast visible and show the error in the dashboard's update row. The row is
red and elides to fit; hovering reveals the complete diagnostic. If no cache is
available, the same row still exposes why the forecast is unavailable.

When many cities are saved, the list must remain scrollable.

## Potential future improvements

Only if requested:
- reorder saved cities;
- pin favorite city;
- keyboard navigation;
- weather alerts;
- optional precipitation-focused mini-view.

Do not add these proactively.
