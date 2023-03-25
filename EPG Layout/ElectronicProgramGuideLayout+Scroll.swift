//
//  ElectronicProgramGuideLayout+Scroll.swift
//  tv-ios
//
//  Created by Erinson Villarroel on 23/08/2019.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import INSElectronicProgramGuideLayout

extension INSElectronicProgramGuideLayout {
    
    func scroll(date: Date, offset: CGFloat, animated: Bool) {
        let positionX = xCoordinate(for: date)
        scroll(positionX: positionX, offset: offset, animated: animated)
    }
    
    func scroll(positionX: CGFloat, offset: CGFloat, animated: Bool) {
        guard let collectionView = collectionView else { return }
        
        var contentOffset = CGPoint(x: positionX - offset, y: collectionView.contentOffset.y - collectionView.contentInset.top)
        
        if contentOffset.y > (collectionView.contentSize.height - collectionView.frame.size.height) {
            contentOffset.y = collectionView.contentSize.height - collectionView.frame.size.height
        }
        if contentOffset.y < -collectionView.contentInset.top {
            contentOffset.y = -collectionView.contentInset.top
        }
        if contentOffset.x > (collectionView.contentSize.width - collectionView.frame.size.width) {
            contentOffset.x = collectionView.contentSize.width - collectionView.frame.size.width
        }
        if contentOffset.x < 0.0 {
            contentOffset.x = 0.0
        }
        
        collectionView.setContentOffset(contentOffset, animated: animated)
    }
    
    func scroll(positionY: CGFloat, offset: CGFloat, animated: Bool) {
        guard let collectionView = collectionView else { return }
        
        var contentOffset = CGPoint(x: collectionView.contentOffset.x, y: positionY)
        
        if contentOffset.y > (collectionView.contentSize.height - collectionView.frame.size.height) {
            contentOffset.y = collectionView.contentSize.height - collectionView.frame.size.height
        }
        if contentOffset.y < -collectionView.contentInset.top {
            contentOffset.y = -collectionView.contentInset.top
        }
        if contentOffset.x > (collectionView.contentSize.width - collectionView.frame.size.width) {
            contentOffset.x = collectionView.contentSize.width - collectionView.frame.size.width
        }
        if contentOffset.x < 0.0 {
            contentOffset.x = 0.0
        }
        
        collectionView.setContentOffset(contentOffset, animated: animated)
    }
    
    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, dd.MM"
        return formatter.string(from: date)
    }
    
}
