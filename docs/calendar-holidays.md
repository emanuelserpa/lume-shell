# Calendar and holidays

`bar/CalendarCard.qml` shows the next two holidays below the year-progress
strip using the reusable `components/HolidayPill.qml` component. The list
updates when the dashboard opens and includes today when a holiday falls on
the current date.
The calendar refreshes its local current date every minute, so the day highlight,
year progress, and upcoming holidays remain in sync when the dashboard stays
open across midnight.

`services/HolidayLogic.js` contains the date rules and has no system or network
dependency. It includes recurring Brazilian national holidays, calculates
Good Friday from Easter, and adds Ceará's March 25 Data Magna when the active
weather city identifies Ceará. The dashboard passes the selected saved city's
region, or matches the current weather city against saved cities when weather
uses automatic location.

Municipal holidays and optional public-service days are not included. Their
dates and status vary by city or annual decree, so the pill does not guess. The
system-monitor rows and dashboard-only telemetry polling have been removed;
CPU and memory now appear in the separate top-bar pill documented in
`system-monitor.md`.

The recurring dates follow the federal holiday calendar published by the
[Brazilian government](https://www.sirc.gov.br/feriados-e-indisponibilidades-sirc/).
Ceará's March 25 date is its constitutional Data Magna
([State Constitution](https://www.ceara.gov.br/wp-content/uploads/2017/03/Const-2015-260-200-Atualizada-emenda-86-4.pdf)).

Pure calendar rules are covered by `tests/qml/tst_holiday_logic.qml` and run
with the normal QML test suite in `scripts/validate.sh`.
