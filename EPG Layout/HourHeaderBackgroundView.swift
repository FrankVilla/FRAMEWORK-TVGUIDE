//
//  HourHeaderBackgroundView.swift
//  INSElectronicProgramGuideLayout
//
//  Created by Erinson Villarroel on 6/18/19.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import UIKit

class HourHeaderBackgroundView: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Asset.Colors.codGrayScreen.color
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
