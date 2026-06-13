#if os(iOS)
import SwiftUI
import AVFoundation

struct ScannerView: View {
    @State private var viewModel: ScannerViewModel
    @State private var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    init(repository: any DCIMRepositoryProtocol) {
        _viewModel = State(initialValue: ScannerViewModel(repository: repository))
    }

    var body: some View {
        Group {
            switch authorizationStatus {
            case .authorized:
                cameraView
            case .denied, .restricted:
                deniedView
            default:
                requestView
            }
        }
        .navigationTitle("Scan Asset Tag")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Camera view

    private var cameraView: some View {
        ZStack {
            CameraPreviewRepresentable(onCode: { code in
                Task { await viewModel.handleScannedCode(code) }
            })
            .ignoresSafeArea()

            ScanReticle()

            VStack {
                Spacer()
                scanResultOverlay
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private var scanResultOverlay: some View {
        switch viewModel.result {
        case .idle:
            EmptyView()

        case .scanning:
            HStack(spacing: 12) {
                ProgressView()
                Text("Looking up device…")
                    .font(.subheadline)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .found(let device):
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name ?? device.display)
                            .font(.headline)
                        Label(device.site.name, systemImage: "building.2")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: device.status)
                }

                HStack(spacing: 12) {
                    NavigationLink {
                        DeviceDetailView(device: device, repository: viewModel.repository)
                    } label: {
                        Label("Open", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.reset()
                    } label: {
                        Label("Scan Again", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .notFound(let tag):
            VStack(spacing: 12) {
                Label("No device found for tag: \(tag)", systemImage: "questionmark.circle")
                    .font(.subheadline)
                Button("Try Again") { viewModel.reset() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .error(let error):
            VStack(spacing: 12) {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button("Try Again") { viewModel.reset() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Permission views

    private var deniedView: some View {
        ContentUnavailableView {
            Label("Camera Access Required", systemImage: "camera.fill")
        } description: {
            Text("Camera access was denied. Enable it in Settings to scan asset tags.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var requestView: some View {
        ContentUnavailableView {
            Label("Camera Access Needed", systemImage: "camera")
        } description: {
            Text("Camera access is required to scan device asset tags.")
        } actions: {
            Button("Allow Camera") {
                Task {
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    authorizationStatus = granted ? .authorized : .denied
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Scanning reticle

private struct ScanReticle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(.white.opacity(0.8), lineWidth: 3)
            .frame(width: 260, height: 180)
            .shadow(color: .black.opacity(0.3), radius: 8)
    }
}

// MARK: - AVFoundation camera preview

private struct CameraPreviewRepresentable: UIViewRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        // Store view in coordinator so startCapture() can access it
        // without transferring non-Sendable values across actor boundaries.
        let coordinator = context.coordinator
        coordinator.previewView = view

        Task.detached {
            coordinator.startCapture()
        }

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
    }

    // MARK: - PreviewView

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    // MARK: - Coordinator
    // @unchecked Sendable: programmer takes responsibility for synchronisation.
    // All AVFoundation setup stays inside startCapture(); only dispatch back
    // to main for UIKit property updates.

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
        var session: AVCaptureSession?
        var previewView: PreviewView?
        private let onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func startCapture() {
            let session = AVCaptureSession()
            self.session = session

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)

            let supported = output.availableMetadataObjectTypes
            let desired: [AVMetadataObject.ObjectType] = [.qr, .code128]
            output.metadataObjectTypes = desired.filter { supported.contains($0) }

            session.startRunning()

            // Update the preview layer on the main thread via self (coordinator is
            // @unchecked Sendable, so self can cross isolation boundaries).
            DispatchQueue.main.async {
                self.previewView?.videoPreviewLayer.session = self.session
                self.previewView?.videoPreviewLayer.videoGravity = .resizeAspectFill
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            // Runs on main queue (set via setMetadataObjectsDelegate(_:queue:.main))
            guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = readable.stringValue else { return }
            onCode(value)
        }
    }
}
#else
import SwiftUI

struct ScannerView: View {
    init(repository: any DCIMRepositoryProtocol) {}

    var body: some View {
        ContentUnavailableView(
            "Not Available",
            systemImage: "qrcode.viewfinder",
            description: Text("QR scanning requires iPhone or iPad.")
        )
    }
}
#endif
