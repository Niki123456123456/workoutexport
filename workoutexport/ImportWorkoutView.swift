import SwiftUI
import HealthKit
import CoreLocation

struct ImportWorkoutView: View {
    var healthStore: HKHealthStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFileURL: URL?
    @State private var selectedType: HKWorkoutActivityType = .running
    @State private var isImporterPresented = false

    let workoutTypes: [(HKWorkoutActivityType, String)] = [
        (.running, "Running"),
        (.cycling, "Cycling"),
        (.walking, "Walking"),
        (.hiking, "Hiking"),
        (.swimming, "Swimming")
    ]

    var body: some View {
        Form {
            Section(header: Text("File")) {
                Button(action: { isImporterPresented.toggle() }) {
                    HStack {
                        Image(systemName: "doc")
                        Text(selectedFileURL?.lastPathComponent ?? "Select GPX/KML file")
                    }
                }
                .fileImporter(
                    isPresented: $isImporterPresented,
                    allowedContentTypes: [UTType(filenameExtension: "gpx")!,
                                          UTType(filenameExtension: "kml")!],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        selectedFileURL = urls.first
                    case .failure(let error):
                        print("File import failed: \(error)")
                    }
                }
            }

            Section(header: Text("Workout Type")) {
                Picker("Type", selection: $selectedType) {
                    ForEach(workoutTypes, id: \.0) { type, label in
                        Text(label).tag(type)
                    }
                }
            }

            Section {
                Button("Create Workout") {
                    if let fileURL = selectedFileURL {
                        createWorkout(from: fileURL, type: selectedType)
                    }
                }
                .disabled(selectedFileURL == nil)
            }
        }
        .navigationTitle("Import Workout")
    }

    private func createWorkout(from url: URL, type: HKWorkoutActivityType) {
        let ext = url.pathExtension.lowercased()
        let locations: [CLLocation]
        if ext == "gpx" {
            locations = WorkoutFileParser.parseGPX(url: url)
        } else if ext == "kml" {
            locations = WorkoutFileParser.parseKML(url: url)
        } else {
            print("Unsupported file")
            return
        }

        guard !locations.isEmpty else {
            print("No locations parsed")
            return
        }

        let start = locations.first!.timestamp
        let end = locations.last!.timestamp
        let distanceMeters = totalDistance(locations: locations)

        let workout = HKWorkout(
            activityType: type,
            start: start,
            end: end,
            duration: end.timeIntervalSince(start),
            totalEnergyBurned: nil,
            totalDistance: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
            metadata: nil
        )

        healthStore.save(workout) { success, error in
            if success {
                print("Workout saved!")

                // Attach workout route
                let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
                routeBuilder.insertRouteData(locations) { success, error in
                    if success {
                        routeBuilder.finishRoute(with: workout, metadata: nil) { route, error in
                            if let error = error {
                                print("Error finishing route: \(error)")
                            } else {
                                print("Workout route saved!")
                                DispatchQueue.main.async {dismiss()}
                            }
                        }
                    } else {
                        print("Error inserting route data: \(String(describing: error))")
                    }
                }
            } else {
                print("Error saving workout: \(String(describing: error))")
            }
        }
    }

    private func totalDistance(locations: [CLLocation]) -> Double {
        guard locations.count > 1 else { return 0 }
        var dist: Double = 0
        for i in 1..<locations.count {
            dist += locations[i].distance(from: locations[i-1])
        }
        return dist
    }

}
