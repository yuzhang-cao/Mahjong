//
//  AVCapturePreviewContainer.swift
//  MahjongTing
//
//  Created by caoyuzhang on 3/19/26.
//

import SwiftUI
import AVFoundation
import UIKit

struct AVCapturePreviewContainer: UIViewRepresentable {
    @ObservedObject var manager: AVCaptureTileScanManager

    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = manager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = manager.session
    }

    final class Coordinator: NSObject {
        let manager: AVCaptureTileScanManager

        init(manager: AVCaptureTileScanManager) {
            self.manager = manager
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? PreviewView else { return }
            let point = gesture.location(in: view)
            let devicePoint = view.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
            manager.setFocusPoint(devicePoint)
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
