import MapKit

@MainActor
final class CafeSearchService {
    private var search: MKLocalSearch?

    func cancel() {
        search?.cancel()
        search = nil
    }

    func cafes(in area: CafeSearchArea) async throws -> [NearbyCafe] {
        cancel()
        let request = MKLocalPointsOfInterestRequest(center: area.coordinate, radius: area.radiusMeters)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe])
        let search = MKLocalSearch(request: request)
        self.search = search
        let response = try await search.start()
        try Task.checkCancellation()
        return NearbyCafe.filtered(response.mapItems, in: area)
    }
}
