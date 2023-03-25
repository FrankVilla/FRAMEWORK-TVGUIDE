//
//  SectionHeader.swift
//  INSElectronicProgramGuideLayout
//
//  Created by Erinson Villarroel on 6/17/19.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import UIKit
import Reusable

@objc class SectionHeader: UICollectionReusableView, Reusable, NibLoadable {

    @IBOutlet private weak var iconImageView: UIImageView!
    
    var channelViewModel = ChannelCell.ChannelViewModel() {
        didSet {
            DispatchQueue.main.async {
                self.iconImageView.image = self.channelViewModel.logo
            }
        }
    }
    
    override func prepareForReuse() {
        self.iconImageView.image = nil
    }
}

extension SectionHeader: ImagedView {
    var imageView: UIImageView {
        return iconImageView
    }
}
