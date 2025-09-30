import SwiftUI
import HealthKit

@main
struct workoutexportApp: App {
    
    private let healthStore: HKHealthStore
        
    init() {
        guard HKHealthStore.isHealthDataAvailable() else {
            fatalError("This app requires a device that supports HealthKit")
        }
        healthStore = HKHealthStore()
        requestHealthkitPermissions()
    }
        
    private func requestHealthkitPermissions() {
        // Types we want to read
        let sampleTypesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)! // optional
        ]
        
        // Types we want to write (save workouts + routes + distances)
        let sampleTypesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: sampleTypesToWrite,
                                         read: sampleTypesToRead) { success, error in
            print("Request Authorization -- Success: \(success), Error: \(error?.localizedDescription ?? "nil")")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)
        }
    }
}

extension HKHealthStore: ObservableObject {}
