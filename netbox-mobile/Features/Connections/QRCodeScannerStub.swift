#if os(iOS)
import AVFoundation

enum QRCodeScannerStub {
    static let supportedMetadataObjectTypes: [AVMetadataObject.ObjectType] = [.qr]
}
#endif
