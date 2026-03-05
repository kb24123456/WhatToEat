import MapKit

extension MKMapItem {
    var compatibleCoordinate: CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return location.coordinate
        } else {
            return placemark.coordinate
        }
    }

    var compatibleAddress: String {
        if #available(iOS 26.0, *) {
            if let shortAddress = address?.shortAddress, !shortAddress.isEmpty {
                return shortAddress
            }
            if let fullAddress = address?.fullAddress, !fullAddress.isEmpty {
                return fullAddress
            }
            if let formattedAddress = addressRepresentations?.fullAddress(includingRegion: false, singleLine: true), !formattedAddress.isEmpty {
                return formattedAddress
            }
            return ""
        } else {
            return placemark.title ?? ""
        }
    }

    var compatibleCity: String? {
        if #available(iOS 26.0, *) {
            return addressRepresentations?.cityName
        } else {
            return placemark.locality
        }
    }

    var compatibleDistrict: String? {
        if #available(iOS 26.0, *) {
            let components = compatibleAddress
                .components(separatedBy: CharacterSet(charactersIn: " ,，"))
                .filter { !$0.isEmpty }

            return components.first(where: {
                $0.hasSuffix("区") || $0.hasSuffix("县") || $0.hasSuffix("旗")
            })
        } else {
            return placemark.subLocality
        }
    }
}
