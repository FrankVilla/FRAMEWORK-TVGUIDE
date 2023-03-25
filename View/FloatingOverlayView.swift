//
//  SectionHeader.swift
//  INSElectronicProgramGuideLayout
//
//  Created by Erinson Villarroel on 6/17/19.
//  Copyright © 2019 inspace.io. All rights reserved.
//

import UIKit
import Reusable

protocol FloatingOverlayViewDelegate: class {
    func eventPressed(_ view: UICollectionReusableView)
}

@objc class FloatingOverlayView: UICollectionReusableView, Reusable, NibLoadable {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    
    weak var delegate: FloatingOverlayViewDelegate?
    
    var eventSection = ChannelCell.ChannelViewModel.EventSection() {
        didSet {
            do {
                setNeedsLayout()
            }
            // set values
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.rasterizationScale = UIScreen.main.scale
        layer.shouldRasterize = true
    }
}

extension FloatingOverlayView {
    func configure(with event: Event) {
        eventSection = ChannelCell.ChannelViewModel.EventSection(event: event)
    }
    var timeframe: String {
        return "\(eventSection.startDate.toShortFormatTime())–\(eventSection.endDate.toShortFormatTime())"
    }
}
