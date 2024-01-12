//
//  ViewController.swift
//  MirrorMeLucy
//
//  Created by n113 on 2/10/18.
//  Copyright © 2018 BlackLab. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import Messages

class MessagesViewController: MSMessagesAppViewController {
    
    let captureSession = AVCaptureSession()
    let background = UIImage(named: "Black.png")!
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var missingFaceLayer: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraButton.layer.borderColor = UIColor.blue.cgColor
        cameraButton.layer.borderWidth = 6
        cameraButton.clipsToBounds = true
        configureDevice()
    }
    
    private func getDevice() -> AVCaptureDevice? {
        let discoverSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTelephotoCamera, .builtInWideAngleCamera], mediaType: .video, position: .front)
        return discoverSession.devices.first
    }
    
    private func configureDevice() {
        if let device = getDevice() {
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                device.unlockForConfiguration()
            } catch { print("failed to lock config") }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                captureSession.addInput(input)
            } catch { print("failed to create AVCaptureDeviceInput") }
            
            captureSession.startRunning()
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .utility))
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension MessagesViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let maxSize = CGSize(width: 1024, height: 1024)
        
        if let image = UIImage(sampleBuffer: sampleBuffer)?.flipped()?.imageWithAspectFit(size: maxSize) {
            self.process(for: image) { (resultImage) in
                DispatchQueue.main.async {
                    self.imageView?.image = resultImage
                }
            }
        }
    }
}

extension MessagesViewController {
    func process(for source: UIImage, complete: @escaping (UIImage) -> Void) {
        var background = self.background
        let detectFaceRequest = VNDetectFaceLandmarksRequest { (request, error) in
            if error == nil {
                if let results = request.results as? [VNFaceObservation] {
                    if !results.isEmpty {
                        for faceObservation in results {
                            guard let landmarks = faceObservation.landmarks else {
                                continue
                            }
                            let boundingRect = faceObservation.boundingBox
                            
                            background = self.drawOnImage(source: source, boundingRect: boundingRect, faceLandmarks: landmarks)
                            
                        }
                        DispatchQueue.main.async {
                            self.view.sendSubview(toBack: self.missingFaceLayer)
                        }
                    }
                    if results.isEmpty {
                        DispatchQueue.main.async {
                            self.missingFaceLayer.text = "Bring your face into view, please"
                            self.view.bringSubview(toFront: self.missingFaceLayer)
                        }
                    }
                }
            } else {
                print(error!.localizedDescription)
            }
            complete(background)
        }
        
        let vnImage = VNImageRequestHandler(cgImage: source.cgImage!, options: [:])
        try? vnImage.perform([detectFaceRequest])
    }
    
    func drawOnImage(source: UIImage, boundingRect: CGRect, faceLandmarks: VNFaceLandmarks2D) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(source.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: 0.0, y: source.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        let rectWidth = source.size.width * boundingRect.size.width * 0 + 350
        let rectHeight = source.size.height * boundingRect.size.height *  0 + 350
        
        let rect = CGRect(x: 0, y: 0, width: source.size.width, height: source.size.height)
        context.draw(background.cgImage!, in: rect)
        
        var count = 1
        
        func drawFeature(_ feature: VNFaceLandmarkRegion2D) {
            
            let color = UIColor.clear.cgColor
            context.setFillColor(color)
            
            for point in feature.normalizedPoints {
                
                let textFontAttributes = [
                    NSAttributedStringKey.font: UIFont.systemFont(ofSize: 12),
                    NSAttributedStringKey.foregroundColor: UIColor.white
                ]
                context.saveGState()
                
                context.translateBy(x: 0.0, y: source.size.height)
                context.scaleBy(x: 1.0, y: -1.0)
                
                let x = self.imageView.center.x/2 + point.x * rectWidth
                let y = source.size.height - (self.imageView.center.y + point.y * rectHeight)
                let mp = CGPoint(x: round(x/10 * 10), y: round(y/10 * 10))
                
                context.fillEllipse(in: CGRect(origin: CGPoint(x: mp.x-2.0, y: mp.y-2.0), size: CGSize(width: 1.0, height: 1.0)))
                NSString(format: "%d", count).draw(at: mp, withAttributes: textFontAttributes)
                count += 1
                context.restoreGState()
            }
            
            context.strokePath()
        }
        
        drawFeature(faceLandmarks.faceContour!)
        drawFeature(faceLandmarks.leftEye!)
        drawFeature(faceLandmarks.rightEye!)
        drawFeature(faceLandmarks.leftPupil!)
        drawFeature(faceLandmarks.rightPupil!)
        drawFeature(faceLandmarks.nose!)
        drawFeature(faceLandmarks.noseCrest!)
        drawFeature(faceLandmarks.medianLine!)
        drawFeature(faceLandmarks.outerLips!)
        drawFeature(faceLandmarks.innerLips!)
        drawFeature(faceLandmarks.leftEyebrow!)
        drawFeature(faceLandmarks.rightEyebrow!)
        
        let coloredImg : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return coloredImg
    }
}


