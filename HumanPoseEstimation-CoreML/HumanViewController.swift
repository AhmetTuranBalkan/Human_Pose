//
//  HumanViewController.swift
//  HumanPoseEstimation-CoreML
//
//  Created by Ahmet Turan Balkan on 25.12.2018.
//  Copyright © 2018 ATB. All rights reserved.
//

import UIKit
import Vision
import CoreMedia

class HumanViewController: UIViewController {
    
    public typealias BodyPoint = (point: CGPoint, confidence: Double)
    public typealias DetectObjectsCompletion = ([BodyPoint?]?, Error?) -> Void

    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var poseView: HumanPoseView!
    @IBOutlet weak var labelsTableView: UITableView!
    @IBOutlet weak var fpsLabel: UILabel!
    

    private var tableData: [BodyPoint?] = []
    private let performanceMeasure = Measure()
    typealias EstimationModel = model_cpm
    var coremlModel: EstimationModel? = nil
    

    var request: VNCoreMLRequest!
    var visionModel: VNCoreMLModel! {
        didSet {
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request.imageCropAndScaleOption = .scaleFill
        }
    }
    
 
    var videoCapture: VideoCapture!

    override func viewDidLoad() {
        super.viewDidLoad()
        visionModel = try? VNCoreMLModel(for: EstimationModel().model)
        setUpCamera()
        labelsTableView.dataSource = self
        poseView.setUpOutputComponent()
        performanceMeasure.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    

    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            
            if success {
 
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                self.videoCapture.start()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
}

extension HumanViewController {
 
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
       let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    

    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        self.performanceMeasure.withLabel(with: "endInference")
        
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmap = observations.first?.featureValue.multiArrayValue {

            let n_kpoints_Pose = convert(heatmap: heatmap)
            
            DispatchQueue.main.sync {
                self.poseView.bodyPoints = n_kpoints_Pose
                self.showKeypointsDescription(with: n_kpoints_Pose)
                self.performanceMeasure.stop()
            }
        }
    }
    
    func convert(heatmap: MLMultiArray) -> [BodyPoint?] {
        guard heatmap.shape.count >= 3 else {
            print("heatmap invalid. \(heatmap.shape)")
            return []
        }
        let keypoint_number = heatmap.shape[0].intValue
        let heatmap_width = heatmap.shape[1].intValue
        let heatmap_height = heatmap.shape[2].intValue
     
        var n_kpoints_Pose = (0..<keypoint_number).map { _ -> BodyPoint? in
            return nil
        }
        
        for k in 0..<keypoint_number {
            for i in 0..<heatmap_width {
                for j in 0..<heatmap_height {
                    let index = k*(heatmap_width*heatmap_height) + i*(heatmap_height) + j
                    let confidence = heatmap[index].doubleValue
                    guard confidence > 0 else { continue }
                    if n_kpoints_Pose[k] == nil ||
                        (n_kpoints_Pose[k] != nil && n_kpoints_Pose[k]!.confidence < confidence) {
                        n_kpoints_Pose[k] = (CGPoint(x: CGFloat(j), y: CGFloat(i)), confidence)
                    }
                }
            }
        }
        
        

        n_kpoints_Pose = n_kpoints_Pose.map { kpoint -> BodyPoint? in
            if let kp = kpoint {
                return (CGPoint(x: (kp.point.x+0.5)/CGFloat(heatmap_width),
                                y: (kp.point.y+0.5)/CGFloat(heatmap_height)),
                        kp.confidence)
            } else {
                return nil
            }
        }
        
        return n_kpoints_Pose
    }
    
    func showKeypointsDescription(with n_kpoints_Pose: [BodyPoint?]) {
        self.tableData = n_kpoints_Pose
        self.labelsTableView.reloadData()
    }
}


extension HumanViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        if let pixelBuffer = pixelBuffer {
            self.performanceMeasure.start()
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

// UITableView Data Source
extension HumanViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count// > 0 ? 1 : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
        cell.textLabel?.text = Constant.pointLabels[indexPath.row]
        if let body_point = tableData[indexPath.row] {
            let pointText: String = "\(String(format: "%.3f", body_point.point.x)), \(String(format: "%.3f", body_point.point.y))"
            cell.detailTextLabel?.text = "(\(pointText)), [\(String(format: "%.3f", body_point.confidence))]"
        } else {
            cell.detailTextLabel?.text = "N/A"
        }
        return cell
    }
}



extension HumanViewController: MeasureDelegate {
    func updateMeasure(fps:Int) {
        self.fpsLabel.text = "FPS: \(fps)"
    }
}


//Constant
struct Constant {
    static let pointLabels = [
        "bas\t\t\t", //0
        "boyun\t\t", //1
        
        "R omuz\t", //2
        "R dirsek\t\t", //3
        "R bilek\t\t", //4
        "L omuz\t", //5
        "L dirsek\t\t", //6
        "L bilek\t\t", //7
        
        "R kalca\t\t", //8
        "R diz\t\t", //9
        "R ayakbilegi\t\t", //10
        "L kalca\t\t", //11
        "L diz\t\t", //12
        "L ayakbilegi\t\t", //13
    ]
    
    static let connectingPointIndexs: [(Int, Int)] = [
        (0, 1), // bas-boyun
        
        (1, 2), // boyun-romuz
        (2, 3), // romuz-rdirsek
        (3, 4), // rdirsek-rbilek
        (1, 8), // boyun-rkalca
        (8, 9), // rkalca-rdiz
        (9, 10), // rboyun-rayakbilegi
        
        (1, 5), // boyun-lomuz
        (5, 6), // lomuz-ldirsek
        (6, 7), // ldirsek-lbilek
        (1, 11), // boyun-lkalca
        (11, 12), // lkalca-ldiz
        (12, 13), // ldiz-layakbilegi
    ]
    static let poseLineColor: UIColor = UIColor(displayP3Red: 87.0/255.0,
                                                 green: 255.0/255.0,
                                                 blue: 211.0/255.0,
                                                 alpha: 0.5)
    
    static let colors: [UIColor] = [
        .red,
        .green,
        .blue,
        .cyan,
        .yellow,
        .magenta,
        .orange,
        .purple,
        .brown,
        .black,
        .darkGray,
        .lightGray,
        .white,
        .gray,
    ]
}
