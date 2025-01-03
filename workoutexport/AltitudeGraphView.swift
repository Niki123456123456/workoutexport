import SwiftUI
import Charts
import CoreLocation

struct AltitudeGraphView: View {
    let locations: [CLLocation]
    
    // Transform [CLLocation] -> [AltitudeDataPoint]
    // Each data point has a distance (x-axis) and altitude (y-axis).
    private var altitudeDataPoints: [AltitudeDataPoint] {
        guard !locations.isEmpty else { return [] }
        
        var data: [AltitudeDataPoint] = []
        var totalDistance: Double = 0.0
        var previousLocation = locations.first!
        
        data.append(
            AltitudeDataPoint(distance: 0,
                              altitude: previousLocation.altitude)
        )
        
        // Accumulate the distance between successive points
        for location in locations.dropFirst() {
            let segmentDistance = previousLocation.distance(from: location)
            totalDistance += segmentDistance
            previousLocation = location
            
            data.append(
                AltitudeDataPoint(distance: totalDistance,
                                  altitude: location.altitude)
            )
        }
        
        return data
    }
    
    var body: some View {
        Chart(altitudeDataPoints) { point in
            LineMark(
                x: .value("Distance (m)", point.distance),
                y: .value("Altitude (m)", point.altitude)
            )
            // Optional: Add a symbol to each data point
            // .symbol(Circle())
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .padding()
    }
}

struct AltitudeDataPoint: Identifiable {
    let id = UUID()
    let distance: Double      // in meters
    let altitude: Double      // in meters
}
