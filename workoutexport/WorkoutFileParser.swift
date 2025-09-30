import Foundation
import SwiftUI
import HealthKit
import CoreLocation
import UIKit

enum WorkoutFileParser {
    static func parseGPX(url: URL) -> [CLLocation] {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let parser = XMLParser(data: data)
            
            let delegate = GPXDelegate()
            parser.delegate = delegate
            let success = parser.parse()
               if !success {
                   if let error = parser.parserError {
                       print("Parsing failed: \(error.localizedDescription)")
                   } else {
                       print("Parsing failed with unknown error")
                   }
                   return []
               }
            return delegate.locations
            
        } catch {
            print("❌ Failed to load data from URL: \(url)")
            print("Error: \(error.localizedDescription)")
            return []
        } } else {
            print("❌ Could not access security-scoped resource: \(url)")
            return []
        }
    }

    private class GPXDelegate: NSObject, XMLParserDelegate {
        var locations: [CLLocation] = []

        private var currentLat: Double?
        private var currentLon: Double?
        private var currentEle: Double?
        private var currentTime: Date?
        private var currentElement: String?

        private let dateFormatter: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        
        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) -> Bool {
            return true
        }

        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {
            currentElement = elementName
            if elementName == "trkpt" {
                currentLat = Double(attributeDict["lat"] ?? "")
                currentLon = Double(attributeDict["lon"] ?? "")
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            switch currentElement {
            case "ele": currentEle = Double(trimmed)
            case "time": currentTime = dateFormatter.date(from: trimmed)
            default: break
            }
        }

        func parser(_ parser: XMLParser,
                    didEndElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?) {
            if elementName == "trkpt",
               let lat = currentLat, let lon = currentLon {
                let loc = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    altitude: currentEle ?? 0,
                    horizontalAccuracy: kCLLocationAccuracyBest,
                    verticalAccuracy: kCLLocationAccuracyBest,
                    timestamp: currentTime ?? Date()
                )
                locations.append(loc)

                currentLat = nil
                currentLon = nil
                currentEle = nil
                currentTime = nil
            }
            currentElement = nil
        }
    }

    static func parseKML(url: URL) -> [CLLocation] {
        var locations: [CLLocation] = []
        guard let data = try? Data(contentsOf: url),
              let xml = String(data: data, encoding: .utf8) else { return [] }

        // Find <coordinates> blocks
        let regex = try! NSRegularExpression(pattern: "<coordinates>([\\s\\S]*?)</coordinates>")
        let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))

        for match in matches {
            if let range = Range(match.range(at: 1), in: xml) {
                let coordsBlock = xml[range]
                let coords = coordsBlock.split { $0.isWhitespace || $0.isNewline }
                for entry in coords {
                    let parts = entry.split(separator: ",")
                    if parts.count >= 2,
                       let lon = Double(parts[0]),
                       let lat = Double(parts[1]) {
                        let ele = parts.count > 2 ? Double(parts[2]) ?? 0 : 0
                        let loc = CLLocation(
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            altitude: ele,
                            horizontalAccuracy: kCLLocationAccuracyBest,
                            verticalAccuracy: kCLLocationAccuracyBest,
                            timestamp: Date()
                        )
                        locations.append(loc)
                    }
                }
            }
        }

        return locations
    }
}
