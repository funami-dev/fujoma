class_name IslandClock
## Island time: UTC plus the offset the server reports for the island's time zone (Europe/Berlin).

static var offset_minutes := 60
## For testing lighting and routines: ?hour=21.5 starts the clock at that hour.
static var override_hour := -1.0


static func seconds_of_day() -> float:
	if override_hour >= 0.0:
		return fposmod(override_hour * 3600.0 + Time.get_ticks_msec() / 1000.0, 86400.0)
	return fposmod(Time.get_unix_time_from_system() + offset_minutes * 60.0, 86400.0)


static func hour() -> float:
	return seconds_of_day() / 3600.0


static func label() -> String:
	var s := int(seconds_of_day())
	return "%02d:%02d" % [s / 3600, (s / 60) % 60]


## True if `h` lies in [from, to), where the range may wrap past midnight.
static func in_hours(h: float, from: float, to: float) -> bool:
	if from <= to:
		return h >= from and h < to
	return h >= from or h < to


static func shop_is_open() -> bool:
	return in_hours(hour(), Defs.SHOP_OPEN_HOUR, Defs.SHOP_CLOSE_HOUR)
