import Foundation
import Testing
@testable import netbox_mobile

struct CircuitsModelTests {
    @Test func circuitDecodesDistanceUnitObject() throws {
        let json = """
        {
            "id": 1,
            "cid": "CKT-001",
            "display": "CKT-001",
            "provider": {
                "id": 10,
                "name": "Provider",
                "slug": "provider",
                "description": ""
            },
            "type": {
                "id": 20,
                "name": "Transit",
                "slug": "transit",
                "description": ""
            },
            "status": {
                "value": "active",
                "label": "Active"
            },
            "install_date": null,
            "termination_date": null,
            "commit_rate": 100000,
            "distance": 12.5,
            "distance_unit": {
                "value": "km",
                "label": "Kilometers"
            },
            "description": "",
            "comments": ""
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let circuit = try decoder.decode(Circuit.self, from: Data(json.utf8))

        #expect(circuit.distanceUnit == "km")
    }
}
