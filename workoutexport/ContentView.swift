import SwiftUI
import HealthKit
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var healthStore: HKHealthStore

    @State private var workouts: [HKWorkout] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading workouts…")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if workouts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No workouts found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Please complete a workout before trying to share it.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(workouts, id: \.uuid) { workout in
                        NavigationLink(
                            destination: WorkoutDetailView(
                                workout: workout,
                                healthStore: healthStore
                            )
                        ) {
                            VStack(alignment: .leading) {
                                Text(workout.workoutActivityType.name)
                                    .font(.headline)
                                Text("Distance: \((workout.totalDistance?.doubleValue(for: .meter()) ?? 0.0) / 1000.0, specifier: "%.1f") km")
                                Text("\(workout.startDate, formatter: dateFormatter)")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .onAppear {
                fetchWorkouts { fetchedWorkouts in
                    DispatchQueue.main.async {
                        if let fetchedWorkouts = fetchedWorkouts {
                            workouts = fetchedWorkouts
                        }
                        isLoading = false
                    }
                }
            }
        }
    }

    private func fetchWorkouts(completion: @escaping ([HKWorkout]?) -> Void) {
        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: oneYearAgo, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: HKWorkoutType.workoutType(),
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) {
            _, samples, error in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                completion(nil)
                return
            }
            completion(workouts)
        }
        healthStore.execute(query)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yy HH:mm"
    return formatter
}()

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .hiking: return "Hiking"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        default: return "Workout"
        }
    }
}
