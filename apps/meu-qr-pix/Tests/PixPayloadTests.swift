import XCTest
@testable import MeuQrPix

final class PixPayloadTests: XCTestCase {
    func testCRC16KnownVector() {
        XCTAssertEqual(PixPayload.crc16("123456789"), "29B1")
    }

    func testPayloadEndsWithChecksumOfItsBody() throws {
        let payload = try PixPayload.make(key: "demo@example.invalid", name: "PESSOA DEMO", city: "BRASILIA", amount: "12,50")
        XCTAssertTrue(payload.contains("540512.50"))
        XCTAssertTrue(payload.hasSuffix(PixPayload.crc16(String(payload.dropLast(4)))))
        XCTAssertTrue(payload.contains("br.gov.bcb.pix"))
    }

    func testInvalidAmountIsRejected() {
        XCTAssertThrowsError(try PixPayload.make(key: "demo@example.invalid", name: "DEMO", city: "BRASILIA", amount: "0"))
        XCTAssertThrowsError(try PixPayload.make(key: "demo@example.invalid", name: "DEMO", city: "BRASILIA", amount: "12.345"))
    }
}
