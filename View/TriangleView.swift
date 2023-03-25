//
//  TriangleView.swift
//  tv-ios
//
//  Created by Erinson Villarroel on 7/30/19.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import UIKit

@IBDesignable class LeftTriangleView: UIView {
    @IBInspectable var color: UIColor = Asset.Colors.redBase.color

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.beginPath()
        context.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY / 2))
        context.addLine(to: CGPoint(x: (rect.maxX), y: rect.maxY))
        context.closePath()

        context.setFillColor(color.cgColor)
        context.fillPath()
    }
}

@IBDesignable class RightTriangleView: UIView {

    @IBInspectable var color: UIColor = Asset.Colors.redBase.color

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func draw(_ rect: CGRect) {
        
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.beginPath()
        context.move(to: CGPoint(x: rect.minX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY / 2))
        context.addLine(to: CGPoint(x: (rect.minX), y: rect.maxY))
        context.closePath()

        context.setFillColor(color.cgColor)
        context.fillPath()
    }
}
