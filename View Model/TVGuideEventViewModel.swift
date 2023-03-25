//
//  TVGuideEventViewModel.swift
//  tv-ios
//
//  Created by Erinson Villarroel on 02/09/2019.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import Foundation

struct EventViewModel {
    let channel: Channel
    let event: Event
    let id: String
    let startsAt: Date
    let endsAt: Date
    let title: String
    var recordingStatus : RecordingStatus? = nil
}

extension EventViewModel {
    
    init(with event: Event, channel: Channel) {
        self.init(
            channel: channel,
            event: event,
            id: event.id,
            startsAt: event.startDate,
            endsAt: event.endDate,
            title: event.title
        )
    }
    
    var timeframe: String {
        return "\(startsAt.toShortFormatTime())–\(endsAt.toShortFormatTime())"
    }
    
    
    mutating func updateRecordingStatus(with status:RecordingStatus) {
        recordingStatus = status
    }
}
