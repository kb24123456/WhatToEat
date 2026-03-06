import Foundation

struct RestaurantCityNormalizationResult {
    let city: String
    let district: String
}

enum RestaurantCityNormalizer {
    private static let districtSuffixes = ["特别行政区", "自治县", "自治旗", "新区", "区", "县", "市", "旗"]

    private static let districtAliasResolution: [String: (city: String, district: String)] = {
        var aliasBuckets: [String: Set<String>] = [:]

        for city in RegionManager.shared.allCities {
            for district in RegionManager.shared.getDistricts(for: city) {
                for alias in districtAliases(from: district) {
                    aliasBuckets[alias, default: []].insert("\(city)|\(district)")
                }
            }
        }

        var result: [String: (city: String, district: String)] = [:]
        for (alias, encodedSet) in aliasBuckets {
            guard encodedSet.count == 1, let encoded = encodedSet.first else { continue }
            let parts = encoded.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            result[alias] = (city: parts[0], district: parts[1])
        }
        return result
    }()

    private static let allCanonicalDistricts: [String] = {
        var districts: Set<String> = []
        for city in RegionManager.shared.allCities {
            for district in RegionManager.shared.getDistricts(for: city) {
                districts.insert(sanitize(district))
            }
        }
        return districts.sorted { $0.count > $1.count }
    }()

    static func normalize(
        address: String,
        district: String,
        fallbackCity: String
    ) -> RestaurantCityNormalizationResult {
        let sanitizedAddress = sanitize(address)
        let sanitizedDistrict = sanitize(district)

        if let districtResolution = resolveDistrictText(sanitizedDistrict) {
            return RestaurantCityNormalizationResult(
                city: districtResolution.city,
                district: districtResolution.district
            )
        }

        if let addressResolution = resolveAddressText(sanitizedAddress) {
            return RestaurantCityNormalizationResult(
                city: addressResolution.city,
                district: addressResolution.district
            )
        }

        return RestaurantCityNormalizationResult(
            city: fallbackCity,
            district: sanitizedDistrict
        )
    }

    private static func resolveDistrictText(_ text: String) -> (city: String, district: String)? {
        guard !text.isEmpty else { return nil }
        for alias in districtAliases(from: text) {
            if let resolved = districtAliasResolution[alias] {
                return resolved
            }
        }
        return nil
    }

    private static func resolveAddressText(_ text: String) -> (city: String, district: String)? {
        guard !text.isEmpty else { return nil }

        for district in allCanonicalDistricts {
            guard text.contains(district) else { continue }
            if let resolved = districtAliasResolution[district] {
                return resolved
            }
        }

        return nil
    }

    private static func districtAliases(from raw: String) -> [String] {
        let value = sanitize(raw)
        guard !value.isEmpty else { return [] }

        var aliases: [String] = [value]
        for suffix in districtSuffixes {
            if value.hasSuffix(suffix) && value.count > suffix.count {
                aliases.append(String(value.dropLast(suffix.count)))
            }
        }

        return Array(Set(aliases))
    }

    private static func sanitize(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
