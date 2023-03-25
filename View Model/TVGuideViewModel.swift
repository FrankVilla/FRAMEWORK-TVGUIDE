//
//  TVGuideViewModel.swift
//  tv-ios
//
//  Created by Erinson Villarroel on 02/09/2019.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import Foundation

final class TVGuideViewModel: NSObject {

    var channels: [ChannelViewModel]
    var filteredChannels: [ChannelViewModel]
    var channelList: ChannelList?
    var query = ""

    init(with channels: [Channel]) {
        self.channels = channels.map { channel in
            .init(with: channel)
        }
        self.filteredChannels = self.channels
    }

    var allChannelIds: [String] {
        return channels
            .map { $0.id }
    }

    func updateChannels() {
        filteredChannels = channels
    }

    func search(_ query: String) {
        self.query = query
    }

    func add(_ channelList: ChannelList?) {
        self.channelList = channelList
    }

    func channelListIds() -> [String] {
        guard let personnalChannels = channelList?.channels else {
            return []
        }
        return personnalChannels.map({ $0.id })
    }

    func filterChannels() {
        let channelIds = Set(channelListIds())
        let filteredChannels = channelIds.isEmpty ? channels : channels.filter({ channelIds.contains($0.id) })
        let channelNameQuery = query.lowercased().replacingOccurrences(of: " ", with: "")
        guard !channelNameQuery.isEmpty else {
            self.filteredChannels = filteredChannels
            return
        }
        self.filteredChannels = filteredChannels.filter({
            $0.name.lowercased().replacingOccurrences(of: " ", with: "").contains(channelNameQuery)
        })
    }

    func channelEvent(at indexPath: IndexPath) -> EventViewModel? {
        if filteredChannels[indexPath.section].events.isEmpty || indexPath.row >= filteredChannels[indexPath.section].events.count {
            return nil
        }
        return filteredChannels[indexPath.section].events[indexPath.row]
    }

    func channelEvent(at indexPath: IndexPath, with event: Event) -> EventViewModel? {
        if filteredChannels[indexPath.section].events.isEmpty ||
            indexPath.row >= filteredChannels[indexPath.section].events.count {
            return nil
        }
        return filteredChannels[indexPath.section].events
            .filter { $0.startsAt.isAfter(date: event.startDate) }
            .sorted{ $0.startsAt.isBefore(date: $1.startsAt) }.first
    }

    func channel(id: String) -> ChannelViewModel? {
        return channels.first { $0.id == id }
    }

    func setEvents(_ events: [Event], forChannelId channelId: String) {
        guard let section = (channels.firstIndex { $0.id == channelId }) else {
            return
        }
        channels[section].events = events.map { event in
            .init(with: event, channel: channels[section].channel)
        }
        filterChannels()
    }

    func findIndex(for channel: Channel) -> Int {
        for index in 0..<filteredChannels.count {
            if channel.id == filteredChannels[index].id {
                return index
            }
        }
        return -1
    }

    func addRecordingStatus(with status: RecordingStatus) {
        dlog("#TVG# Add recording status to TV Guide view model: \(status)")
        guard let eventId = status.eventId else  {
            return
        }
        if var event = findEvent(with: eventId) {
            event.updateRecordingStatus(with: status)
        }
    }

    func findEvent(with eventId: String) -> EventViewModel? {
        for channel in filteredChannels {
            if channel.containingEvent(eventId: eventId) {
                return channel.events.first {
                    $0.id == eventId
                }
            }
        }
        return nil
    }

    func indexPath(for event: Event) -> IndexPath? {
        guard let (section, channel) = self.filteredChannels.enumerated()
            .first(where: { $1.containingEvent(event: event)}) else {
            return nil
        }
        guard let (item, _) = channel.events.enumerated().first(where: { $1.id == event.id }) else {
            return nil
        }
        return IndexPath(item: item, section: section)
    }

    func findIndex(for event: Event, row: Int) -> Int {
        let channel = filteredChannels[row]
        for index in 0..<channel.events.count {
            if event.id == channel.events[index].id {
                return index
            }
        }
        return -1
    }
}
