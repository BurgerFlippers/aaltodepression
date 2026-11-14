import Foundation
import CoreLocation

// Calendar and photo library are outside the agreed data scope (docs/DATA_SCOPE.md).
// These stubs keep existing callers compiling while reading nothing and asking for nothing.
// TODO(integrator): remove the CalendarSource / PhotosSource calls from AppModel, then delete this file
// and the NSCalendarsFullAccessUsageDescription / NSPhotoLibraryUsageDescription build settings.

nonisolated enum CalendarSource {
    static func requestAccess() async {}
    static func read(days: Int = 365, calendar: Calendar = .current) -> FeatureTable { FeatureTable() }
}

nonisolated enum PhotosSource {
    static func requestAccess() async {}
    static func read(home: CLLocation?, days: Int = 365, calendar: Calendar = .current) -> FeatureTable { FeatureTable() }
}
