import Foundation

/// Sunrise, sunset and day length from the NOAA solar calculator equations
/// (Meeus, "Astronomical Algorithms"). Pure and thread-safe; Foundation only.
/// Accuracy is about one minute for latitudes within the polar circles and a
/// few minutes near them, where the sun skims the horizon.
nonisolated enum Solar {

    /// Sun times for the calendar day that `date` falls on in `timeZone`.
    /// Sunrise and sunset are nil on polar day (24 h) and polar night (0 h).
    /// Uses the standard zenith of 90.833 degrees (refraction plus solar radius).
    static func times(date: Date, latitude: Double, longitude: Double, timeZone: TimeZone)
        -> (sunrise: Date?, sunset: Date?, dayLengthHours: Double)
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = day.year, let m = day.month, let d = day.day else {
            return (nil, nil, 0)
        }

        // Midnight UTC of the local calendar date; event times are minutes after it.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        guard let utcMidnight = utc.date(from: DateComponents(year: y, month: m, day: d)) else {
            return (nil, nil, 0)
        }
        let jdMidnight = utcMidnight.timeIntervalSince1970 / 86_400 + 2_440_587.5

        // Polar check at approximate local solar noon.
        let noon = 720 - 4 * longitude
        let noonSun = sun(julianDay: jdMidnight + noon / 1440)
        guard let noonHA = hourAngle(latitude: latitude, declination: noonSun.declination) else {
            // Sun above horizon at noon -> never sets; below -> never rises.
            let elevation = 90 - abs(latitude - noonSun.declination)
            return (nil, nil, elevation > -0.833 ? 24 : 0)
        }

        // Refine each event by recomputing the sun's position at the event time.
        // Near the polar limit the refined position can leave the valid range;
        // clamping keeps the event at the culmination instead of dropping it.
        func event(_ sign: Double, start: Double) -> Double {
            var minutes = start
            for _ in 0..<3 {
                let s = sun(julianDay: jdMidnight + minutes / 1440)
                let ha = hourAngle(latitude: latitude, declination: s.declination, clamped: true) ?? noonHA
                minutes = 720 - 4 * (longitude + sign * ha) - s.equationOfTime
            }
            return minutes
        }

        let riseGuess = 720 - 4 * (longitude + noonHA) - noonSun.equationOfTime
        let setGuess = 720 - 4 * (longitude - noonHA) - noonSun.equationOfTime
        let rise = event(1, start: riseGuess)
        let set = event(-1, start: setGuess)

        return (utcMidnight.addingTimeInterval(rise * 60),
                utcMidnight.addingTimeInterval(set * 60),
                (set - rise) / 60)
    }

    // MARK: - NOAA equations

    /// Sunrise hour angle in degrees, or nil when the sun does not cross the
    /// horizon (unless `clamped`, which pins it to 0 or 180 degrees).
    private static func hourAngle(latitude: Double, declination: Double, clamped: Bool = false) -> Double? {
        let lat = latitude * .pi / 180, dec = declination * .pi / 180
        var cosHA = cos(90.833 * .pi / 180) / (cos(lat) * cos(dec)) - tan(lat) * tan(dec)
        if clamped { cosHA = min(1, max(-1, cosHA)) }
        guard cosHA >= -1, cosHA <= 1 else { return nil }
        return acos(cosHA) * 180 / .pi
    }

    /// Declination (degrees) and equation of time (minutes) at a Julian day.
    private static func sun(julianDay jd: Double) -> (declination: Double, equationOfTime: Double) {
        let rad = Double.pi / 180
        let t = (jd - 2_451_545) / 36_525

        let l0 = (280.46646 + t * (36_000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let m = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let c = sin(m * rad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * m * rad) * (0.019993 - 0.000101 * t)
            + sin(3 * m * rad) * 0.000289
        let trueLong = l0 + c
        let omega = 125.04 - 1934.136 * t
        let apparentLong = trueLong - 0.00569 - 0.00478 * sin(omega * rad)

        let meanObliq = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliq = meanObliq + 0.00256 * cos(omega * rad)

        let declination = asin(sin(obliq * rad) * sin(apparentLong * rad)) / rad

        var y = tan(obliq * rad / 2)
        y *= y
        let eqTime = y * sin(2 * l0 * rad)
            - 2 * e * sin(m * rad)
            + 4 * e * y * sin(m * rad) * cos(2 * l0 * rad)
            - 0.5 * y * y * sin(4 * l0 * rad)
            - 1.25 * e * e * sin(2 * m * rad)

        return (declination, 4 * eqTime / rad)
    }
}
