//
//  HourHeader.swift
//  INSElectronicProgramGuideLayout
//
//  Created by Erinson Villarroel on 6/17/19.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import UIKit
import Reusable

class HourHeader: UICollectionReusableView, Reusable, NibLoadable {
    
    @IBOutlet weak var timeLabel: UILabel!
    
    var time: Date?

    @objc func setTime(_ time: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        self.time = time
        
        timeLabel.text = formatter.string(from: time)
        
        setNeedsLayout()
    }
}

