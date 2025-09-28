import SwiftUI
import MapKit

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    var annotations: [MKPointAnnotation]
    var zoomLevel: Double?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = .none
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped(_:)))
        map.addGestureRecognizer(gesture)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeAnnotations(uiView.annotations.filter { !($0 is MKUserLocation) })
        uiView.addAnnotations(annotations)
        
        // zoomLevelが指定されている場合はそれを使用
        let region = MKCoordinateRegion(
            center: centerCoordinate,
            span: zoomLevel != nil
                ? MKCoordinateSpan(latitudeDelta: zoomLevel!, longitudeDelta: zoomLevel!)
                : MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
        uiView.setRegion(region, animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        init(_ parent: MapViewRepresentable) { self.parent = parent }

        @objc func mapTapped(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let pt = gesture.location(in: map)
            let coord = map.convert(pt, toCoordinateFrom: map)
            parent.selectedCoordinate = coord
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            let id = "place"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view?.canShowCallout = true
            } else {
                view?.annotation = annotation
            }
            return view
        }
    }
}
