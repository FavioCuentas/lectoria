import Testing
import Foundation
@testable import Lectoria

@MainActor
struct DeviceIdentityTests {
    /// El progreso sincronizado debe llevar el identificador real del dispositivo, estable entre llamadas.
    @Test func testCurrentIsStableAndNotPlaceholder() {
        let first = DeviceIdentity.current
        #expect(!first.isEmpty)
        #expect(first != "iOS-Simulator")
        #expect(DeviceIdentity.current == first)
    }
}
