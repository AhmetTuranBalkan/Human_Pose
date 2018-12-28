//
//  Measure.swift
//  HumanPoseEstimation-CoreML
//
//  Created by Ahmet Turan Balkan on 25.12.2018.
//  Copyright © 2018 ATB. All rights reserved.
//

import UIKit

protocol MeasureDelegate {
    func updateMeasure(fps: Int)
}
// Performance Measurement
class Measure {
    
    var delegate: MeasureDelegate?
    
    var index: Int = -1
    var measurements: [Dictionary<String, Double>]
    
    init() {
        let measurement = [
            "start": CACurrentMediaTime(),
            "end": CACurrentMediaTime()
        ]
        measurements = Array<Dictionary<String, Double>>(repeating: measurement, count: 30)
    }
    

    func start() {
        index += 1
        index %= 30
        measurements[index] = [:]
        
        withLabel(for: index, with: "start")
    }
    
 
    func stop() {
        withLabel(for: index, with: "end")
        
        let beforeMeasurement = getBeforeMeasurment(for: index)
        let currentMeasurement = measurements[index]
        if let startTime = currentMeasurement["start"],
           let beforeStartTime = beforeMeasurement["start"] {
            delegate?.updateMeasure(fps: Int(1/(startTime - beforeStartTime)))
        }
        
    }
    
    // labeling with
    func withLabel(with msg: String? = "") {
        withLabel(for: index, with: msg)
    }
    
    private func withLabel(for index: Int, with msg: String? = "") {
        if let message = msg {
            measurements[index][message] = CACurrentMediaTime()
        }
    }
    
    private func getBeforeMeasurment(for index: Int) -> Dictionary<String, Double> {
        return measurements[(index + 30 - 1) % 30]
    }
    
    func printLog() {
        
    }
}

class MeasureLogView: UIView {
    let etimeLabel = UILabel(frame: .zero)
    let fpsLabel = UILabel(frame: .zero)
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
