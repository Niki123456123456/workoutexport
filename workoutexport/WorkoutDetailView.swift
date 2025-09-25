import SwiftUI
import HealthKit
import CoreLocation
import UIKit

struct WorkoutDetailView: View {
    let workout: HKWorkout
    let healthStore: HKHealthStore
    
    @State private var locations: [CLLocation] = []
    

    var body: some View {
        VStack() {
            Text("Type: \(workout.workoutActivityType.name)")
            Text("Distance: \((workout.totalDistance?.doubleValue(for: .meter()) ?? 0.0) / 1000.0, specifier: "%.1f") km")
            Text("Duration: \(formatTimeInterval(workout.duration))")
            Text("\(workout.startDate, formatter: dateFormatter) - \(workout.endDate, formatter: dateFormatter)")
            
            if locations.isEmpty {
                            Text("No route available")
                                .foregroundColor(.gray)
                        } else {
                            MapView(locations: locations)
                                .frame(height: 300)
                            
                            AltitudeGraphView(locations: locations)
                                           .frame(height: 300)
                        }
            
            
        }.onAppear {
            fetchWorkoutRoute(for: workout) { locations2 in
                                                    if let locations2 = locations2 {
                                                        locations = locations2
                                                    }
                                                }
        } .toolbar {
            if !locations.isEmpty {
                            ShareLink(item: createGPXFile(), label: {
                                Text("GPX")
                            })
                
                            ShareLink(item: createKMLFile(), label: {
                                Text("KML")
                            })
                        }
        }
    }
    
    
    func fetchWorkoutRoute(for workout: HKWorkout, completion: @escaping ([CLLocation]?) -> Void) {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        
        let query = HKAnchoredObjectQuery(type: routeType,
                                          predicate: predicate,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit) { _, samples, _, _, error in
            
            guard let routes = samples as? [HKWorkoutRoute], error == nil else {
                completion(nil)
                return
            }
            
            var routeLocations: [CLLocation] = []
            
            let group = DispatchGroup()
            for route in routes {
                group.enter()
                
                let routeQuery = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                    if let locations = locations, error == nil {
                        routeLocations.append(contentsOf: locations)
                    }
                    if done {
                        group.leave()
                    }
                }
                
                self.healthStore.execute(routeQuery)
            }
            
            group.notify(queue: .main) {
                completion(routeLocations)
            }
        }
        
        healthStore.execute(query)
    }
    
    func createGPXFile() -> URL {
        let gpxString = generateGPX(from: locations)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("workout.gpx")
        
        do {
            try gpxString.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("Could not create GPX file: \(error)")
        }
        return tempURL
    }
    func createKMLFile() -> URL {
        let gpxString = generateKML(from: locations)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("workout.kml")
        
        do {
            try gpxString.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("Could not create GPX file: \(error)")
        }
        return tempURL
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yy HH:mm"
    return formatter
}()

func formatTimeInterval(_ interval: TimeInterval) -> String {
    let totalSeconds = Int(interval)
    
    if totalSeconds < 3600 {
        // Less than 1 hour -> "X min Y s"
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes) min \(seconds) s"
    } else {
        // 1 hour or more -> "X h Y min Z s"
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = (totalSeconds % 3600) % 60
        return "\(hours) h \(minutes) min \(seconds) s"
    }
}



func generateGPX(from locations: [CLLocation]) -> String {
    guard !locations.isEmpty else {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="MyApp" xmlns="http://www.topografix.com/GPX/1/1">
        </gpx>
        """
    }

    var gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="MyApp" xmlns="http://www.topografix.com/GPX/1/1">
      <trk>
        <trkseg>
    """

    // Optional: for time tags
    let isoFormatter = ISO8601DateFormatter()

    for loc in locations {
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        let time = isoFormatter.string(from: loc.timestamp)
        let ele = loc.altitude         // Altitude in meters

        gpx += """
            <trkpt lat="\(lat)" lon="\(lon)">
              <ele>\(ele)</ele>
              <time>\(time)</time>
            </trkpt>
        """
    }

    gpx += """
        </trkseg>
      </trk>
    </gpx>
    """

    return gpx
}

func generateKML(from locations: [CLLocation]) -> String {
    // If we have no locations, provide a basic KML structure with no data
    guard !locations.isEmpty else {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
            <Document>
                <name>MyApp</name>
                <Placemark>
                    <name>No route data</name>
                    <description>No route data available</description>
                </Placemark>
            </Document>
        </kml>
        """
    }
    
    // Build a coordinate string in the format "lon,lat,alt lon,lat,alt ..."
    // For a KML `LineString`, altitude is optional — you could pass 0 if altitude is unnecessary
    var coordinatesString = ""
    for location in locations {
        let lon = location.coordinate.longitude
        let lat = location.coordinate.latitude
        let alt = location.altitude  // can be 0 if altitude is unknown or unnecessary
        coordinatesString.append("\(lon),\(lat),\(alt) ")
    }
    
    // Construct the KML with a single Placemark and LineString
    let kml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <kml xmlns="http://www.opengis.net/kml/2.2">
        <Document>
            <name>MyApp KML</name>
            <Placemark>
                <name>Workout Route</name>
                <description>Route recorded from CLLocation</description>
                <LineString>
                    <coordinates>\(coordinatesString)</coordinates>
                </LineString>
            </Placemark>
        </Document>
    </kml>
    """
    
    return kml
}
