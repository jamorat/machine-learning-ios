//
//  RecognizeObjectUseCase.swift
//  SampleProject
//
//  Created by Jack Amoratis on 12/22/18.
//  Copyright © 2018 John Amoratis. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import Vision
import RxSwift
import RxCocoa

class RecognizeObjectUseCase: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var previewLayer: AVCaptureVideoPreviewLayer!
    var analyzedObject: ReplaySubject<AnalyzedObject>!
    var isAnalyzing: ReplaySubject<Bool>!
    var imageForImageView : UIImage!
    var captureSession: AVCaptureSession!
    var newTap = false
    var isPaused = true
    
    private var currentBuffer: CVPixelBuffer?
    
    override init() {
        super.init()
        analyzedObject = ReplaySubject<AnalyzedObject>.create(bufferSize: 1)
        initializeSession()
    }
    
    func initializeSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.cif352x288
        
        let videoCaptureDevice: AVCaptureDevice = AVCaptureDevice.default(for: .video)!
        
        let videoCaptureInput = try! AVCaptureDeviceInput(device: videoCaptureDevice)
        captureSession.addInput(videoCaptureInput)
        
        let captureOutput = AVCaptureVideoDataOutput()
//        captureOutput.videoSettings = ["AVVideoScalingModeKey":AVVideoScalingModeResizeAspectFill, "AVVideoWidthKey" : 90,
//            "AVVideoHeightKey" : 90]
        captureOutput.setSampleBufferDelegate(self, queue: .main)
        captureSession.addOutput(captureOutput)
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        captureSession.startRunning()
        newTap = true
        isPaused = false
    }
    
    func buttonTapped(){
        setActivityState(to: "notPaused")
        newTap = true
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        
        let imageBuffer: CVImageBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)!
        guard imageBuffer != nil else { return }


        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: imageBuffer!, options: attachments as? [CIImageOption : Any])

        let image = UIImage(ciImage: ciImage)
        if newTap == true && isPaused == false {
            print("new tap")
            newTap = false
            imageForImageView = image
            currentBuffer = image.buffer()
        }
        
        classifyCurrentImage() //classifies currentBuffer
        
    }
    
    private func classifyCurrentImage() {
        // Most computer vision tasks are not rotation agnostic so it is important to pass in the orientation of the image with respect to device.
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(UIDevice.current.orientation.rawValue))
        
        guard currentBuffer != nil else {
            return
        }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: currentBuffer!, orientation: orientation!)
        do {
            defer { self.currentBuffer = nil }
            try requestHandler.perform(classificationRequest())
        } catch {
            print("Error: Vision request failed with error \"\(error)\"")
        }
    }
    
    func setActivityState(to state: String) {
        print("activity state set to: \(state)")
        if state == "paused" {
            captureSession.stopRunning()
            isPaused = true
        }else{
            captureSession.startRunning()
            isPaused = false
        }
    }
    
    func classificationRequest() -> [VNCoreMLRequest] {
        do {
            // Instantiate the model from its generated Swift class.
            let model = try VNCoreMLModel(for: Inceptionv3().model)
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                print("completion handler above")
                dump(request)
                self?.processClassifications(for: request, error: error)
                print("completion handler below")
            })
            
            request.imageCropAndScaleOption = .centerCrop
            
            request.usesCPUOnly = true
            
            return [request]
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }
    
    func processClassifications(for request: VNRequest, error: Error?) {
        guard let results = request.results else {
            print("Unable to classify image.\n\(error!.localizedDescription)")
            return
        }
        let classifications = results as! [VNClassificationObservation]
        
        if let bestResult = classifications.first(where: { result in result.confidence > 0.5 })
             {
            //print("THE MAIN EVENT ANSWER: \(label)")
            dump(bestResult.identifier)
            print("confidence: \(bestResult.confidence)")
            let roundedConfidence: Double = Double(100 * bestResult.confidence).rounded(toPlaces: 2)
            //imageForImageView.imageOrientation = .up
            DispatchQueue.main.async { [weak self] in
                self?.analyzedObject.onNext(AnalyzedObject(labelText: "\(bestResult.identifier.replacingOccurrences(of: ",", with: "\n"))", image: (self?.imageForImageView)!))
            }
            
            
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.newTap = true
        }
    }
}
