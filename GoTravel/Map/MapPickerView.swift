import SwiftUI
import MapKit
import CoreLocation

// A simple MKMapView wrapper that lets the user tap to place a pin.
struct MapPickerView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D?
    var showsUserLocation: Bool = true

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = showsUserLocation
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        map.addGestureRecognizer(gesture)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeAnnotations(uiView.annotations.filter { !($0 is MKUserLocation) })
        if let coord = coordinate {
            let ann = MKPointAnnotation()
            ann.coordinate = coord
            uiView.addAnnotation(ann)
            uiView.setCenter(coord, animated: true)
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800)
            uiView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapPickerView
        init(_ parent: MapPickerView) { self.parent = parent }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let map = gesture.view as! MKMapView
            let point = gesture.location(in: map)
            let coord = map.convert(point, toCoordinateFrom: map)
            parent.coordinate = coord
        }
    }
}
