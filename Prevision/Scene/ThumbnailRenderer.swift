import RealityKit
import UIKit
import Metal
import CoreGraphics

enum ThumbnailRenderer {
    @MainActor
    static func render(modelAt url: URL, zUp: Bool, pixelSize: Int = 480) async -> UIImage? {
        do {
            let entity = try await Entity(contentsOf: url)
            if zUp {
                let correction = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
                entity.transform.rotation = correction * entity.transform.rotation
            }

            let bounds = entity.visualBounds(relativeTo: nil)
            let center = bounds.center
            let radius = bounds.boundingRadius
            guard radius.isFinite, radius > 0 else { return nil }

            let camera = PerspectiveCamera()
            camera.camera = PerspectiveCameraComponent(near: 0.01, far: 1000, fieldOfViewInDegrees: 30)

            let yaw: Float = 35 * .pi / 180
            let pitch: Float = 25 * .pi / 180
            let halfFov = (30 * Float.pi / 180) / 2
            let distance = max(radius / sin(halfFov) * 1.4, 0.05)
            let direction = SIMD3<Float>(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
            camera.look(at: center, from: center + direction * distance, upVector: SIMD3<Float>(0, 1, 0), relativeTo: nil)

            let light = DirectionalLight()
            light.light.intensity = 4000
            light.look(at: center, from: center + SIMD3<Float>(0.4, 1, 0.6), relativeTo: nil)

            let renderer = try RealityRenderer()
            renderer.entities.append(contentsOf: [entity, camera, light])
            renderer.activeCamera = camera
            renderer.cameraSettings.colorBackground = .color(UIColor(white: 0.96, alpha: 1).cgColor)

            guard let device = MTLCreateSystemDefaultDevice() else { return nil }
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm_srgb,
                width: pixelSize,
                height: pixelSize,
                mipmapped: false
            )
            textureDescriptor.usage = [.renderTarget, .shaderRead]
            textureDescriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return nil }

            let cameraOutputDescriptor = RealityRenderer.CameraOutput.Descriptor.singleProjection(colorTexture: texture)
            let cameraOutput = try RealityRenderer.CameraOutput(cameraOutputDescriptor)

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    try renderer.updateAndRender(
                        deltaTime: 1.0 / 60.0,
                        cameraOutput: cameraOutput,
                        onComplete: { _ in
                            continuation.resume()
                        }
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            guard let cgImage = Self.cgImage(from: texture) else { return nil }
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    private static func cgImage(from texture: MTLTexture) -> CGImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        let region = MTLRegionMake2D(0, 0, width, height)
        data.withUnsafeMutableBytes { buffer in
            texture.getBytes(buffer.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
