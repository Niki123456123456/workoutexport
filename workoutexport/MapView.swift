import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    let locations: [CLLocation]

        var body: some View {
            // Extrahiere nur die CLLocationCoordinate2D aus deinen CLLocation-Objekten
            let coordinates = locations.map { $0.coordinate }

            LineMapView(coordinates: coordinates)
                .edgesIgnoringSafeArea(.all)
        }
}


struct Polyline: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    
    init(locations: [CLLocation]) {
        self.coordinates = locations.map { $0.coordinate }
    }
}


struct LineMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    /// Erzeugt und konfiguriert den MKMapView.
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        return mapView
    }

    /// Aktualisiert den MKMapView bei Änderungen (z.B. neuen Koordinaten).
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Entferne zuvor hinzugefügte Overlays
        uiView.removeOverlays(uiView.overlays)

        // Erzeuge ein MKPolyline-Objekt aus den Koordinaten
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        uiView.addOverlay(polyline)

        guard !coordinates.isEmpty else { return }
                
                // 1. Berechne den geografischen Mittelpunkt aller Koordinaten.
                let centerCoordinate = calculateCenter(coordinates: coordinates)
                
                // 2. Ermittle die größte Distanz (in Metern) zwischen allen Punkten,
                //    damit wir diese als "Basis" für latitudinalMeters/longitudinalMeters nehmen können.
                let biggestDistance = calculateBiggestDistance(coordinates: coordinates, center: centerCoordinate)
                
                // 3. Einen 5%-Puffer draufschlagen:
                let adjustedDistance = biggestDistance * 1.2
                
                // 4. Erzeuge und setze das neue Region-Objekt
                let region = MKCoordinateRegion(
                    center: centerCoordinate,
                    latitudinalMeters: adjustedDistance,
                    longitudinalMeters: adjustedDistance
                )
                
                uiView.setRegion(region, animated: true)
    }

    /// Erstellt den Coordinator, der die MKMapViewDelegate-Methoden umsetzt.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Coordinator als MKMapViewDelegate für das Zeichnen der Linie.
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LineMapView

        init(_ parent: LineMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .blue       // Farbe der Linie
            renderer.lineWidth = 3             // Dicke der Linie
            return renderer
        }
    }
}


extension LineMapView {
    
    private func calculateCenter(coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
                   return CLLocationCoordinate2D(latitude: 0, longitude: 0)
               }
               
               guard let minLat = coordinates.map({ $0.latitude }).min(),
                     let maxLat = coordinates.map({ $0.latitude }).max(),
                     let minLon = coordinates.map({ $0.longitude }).min(),
                     let maxLon = coordinates.map({ $0.longitude }).max()
               else {
                   return coordinates.first!
               }

               let centerLat = minLat + (maxLat - minLat) / 2
               let centerLon = minLon + (maxLon - minLon) / 2
               
               return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }
    
    private func calculateBiggestDistance(coordinates: [CLLocationCoordinate2D],
                                          center: CLLocationCoordinate2D) -> Double {
        
        guard let minLat = coordinates.map({ $0.latitude }).min(),
              let maxLat = coordinates.map({ $0.latitude }).max(),
              let minLon = coordinates.map({ $0.longitude }).min(),
              let maxLon = coordinates.map({ $0.longitude }).max()
        else {
            return 1000 // Fallback
        }
        
        // Umrechnung: ca. 111.111 Meter pro Breitengrad
        let latMeters = (maxLat - minLat) * 111_111
        
        // Umrechnung Längengrad -> Meter hängt vom Breitengrad ab (cos(latitude))
        // zur Vereinfachung verwenden wir den Mittelpunkt oder den Durchschnitt
        let centerLatRad = center.latitude * .pi / 180
        let lonMeters = (maxLon - minLon) * 111_111 * cos(centerLatRad)
        
        // Wir nehmen die größere Ausdehnung zwischen Höhe (latMeters) oder Breite (lonMeters)
        let maxEdge = max(abs(latMeters), abs(lonMeters))
        
        // Falls du wirklich nur die Differenz in der Höhe möchtest (latitudinalMeters),
        // könntest du auch nur latMeters verwenden.
        
        return maxEdge
    }
}
