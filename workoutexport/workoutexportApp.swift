import SwiftUI
import HealthKit

@main
struct workoutexportApp: App {
    
    private let healthStore: HKHealthStore
        
        init() {
            guard HKHealthStore.isHealthDataAvailable() else {  fatalError("This app requires a device that supports HealthKit") }
            healthStore = HKHealthStore()
            requestHealthkitPermissions()
        }
        
        private func requestHealthkitPermissions() {
            
            let sampleTypesToRead = Set([
                HKObjectType.workoutType(),
                HKSeriesType.workoutRoute(),
                HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                HKObjectType.quantityType(forIdentifier: .distanceCycling)!
            ])
            
            healthStore.requestAuthorization(toShare: nil, read: sampleTypesToRead) { (success, error) in
                print("Request Authorization -- Success: ", success, " Error: ", error ?? "nil")
            }
        }
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(healthStore)
        }
    }
}

extension HKHealthStore: ObservableObject{}
