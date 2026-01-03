import MapKit


func mapItemCoordinate(_ item: MKMapItem) -> CLLocationCoordinate2D? {
    if #available(iOS 26.0, *) {
        return item.location.coordinate
    } else {
        return legacyMapItemCoordinate(item)
    }
}

func mapItemCity(_ item: MKMapItem) -> String? {
    if #available(iOS 26.0, *) {
        return item.addressRepresentations?.cityWithContext
    } else {
        return legacyMapItemCity(item)
    }
}

func mapItemAddressString(_ item: MKMapItem) -> String? {
    if #available(iOS 26.0, *) {
        let addr: String? = item.address?.fullAddress ?? item.address?.shortAddress
        return addr
    } else {
        return legacyMapItemAddressString(item)
    }
}

@available(iOS, introduced: 17.0, obsoleted: 26.0)
private func legacyMapItemCoordinate(_ item: MKMapItem) -> CLLocationCoordinate2D? {
    item.placemark.coordinate
}

@available(iOS, introduced: 17.0, obsoleted: 26.0)
private func legacyMapItemCity(_ item: MKMapItem) -> String? {
    item.placemark.locality ?? item.placemark.administrativeArea
}

@available(iOS, introduced: 17.0, obsoleted: 26.0)
private func legacyMapItemAddressString(_ item: MKMapItem) -> String? {
    item.placemark.title
}

