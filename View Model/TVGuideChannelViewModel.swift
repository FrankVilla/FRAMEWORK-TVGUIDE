//
//  TVGuideChannelViewModel.swift
//  tv-ios
//
//  Created by Erinson Villarroel on 02/09/2019.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import Foundation
import UIKit

class ChannelViewModel: NSObject {
    let channel: Channel
    let id: String
    var name: String
    var image: FetchableValue<UIImage>?
    var events: [EventViewModel] = []
    
    init(with channel: Channel) {
        self.channel = channel
        self.id = channel.id
        self.name = channel.name
        self.image = channel.logoPicture
        super.init()
    }
    
    func insertEvents(with events: [Event]) {
        var newEvents : [EventViewModel] = []
        events.forEach { (event) in
            let evm = EventViewModel(with: event, channel: channel)
            newEvents.append(evm)
        }
        self.events = newEvents
    }
    
    func insertEvent(event:Event) {
        //if event not in view model insert event into place
        if !containingEvent(event: event) {
            let insertIndex = findInsertIndex(for: event)
            let evm = EventViewModel(with: event, channel: channel)
            self.events.insert(evm, at: insertIndex)
        }
    }
    
    func containingEvent(event:Event) -> Bool {
        return events.filter { (evm) -> Bool in
            return evm.id == event.id
        }.count > 0
    }
    
    func containingEvent(eventId:String) -> Bool {
        events.contains {
            $0.id == eventId
        }
    }
    
    func findInsertIndex(for event:Event) -> Int {
        return events.endIndex
    }
 
    func updateRecordingStatuses(with statuses: [RecordingStatus]) {
        for (n, ev) in events.enumerated() {
            let filteredStatuses = statuses.filter({ (recStatus) -> Bool in
                return recStatus.eventId == ev.id
            })
            if filteredStatuses.count > 0, let status = filteredStatuses.first {
                events[n].updateRecordingStatus(with: status)
            }
        }
    }
}
