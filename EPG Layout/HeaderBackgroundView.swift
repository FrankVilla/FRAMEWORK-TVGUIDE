//
//  HeaderBackgroundView.swift
//  INSElectronicProgramGuideLayout
//
//  Created by Mac on 6/17/19.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import UIKit

class HeaderBackgroundView: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
