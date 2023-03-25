//
//  TVDataSource.swift
//  tv-ios
//
//  Created by Milosz Milewski on 06/02/2020.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import Foundation
import INSElectronicProgramGuideLayout
import SwiftDate

class TVDataSource: NSObject, Networked, TVGuideCoordinated {
    let networkIdentifier = NetworkIdentifier()

    var tvGuideCoordinator: TVGuideFlowCoordinator?

    var networkController: NetworkController?

    var viewModel: TVGuideViewModel
    var date: Date
    var recordingStatuses: [RecordingStatus] = []
    init(with channels: [Channel], date: Date) {
        self.viewModel = TVGuideViewModel(with: channels)
        self.date = date
        super.init()
    }

    func imageLogo(at indexPath: IndexPath) -> FetchableValue<UIImage>? {
        return viewModel.filteredChannels[indexPath.section].image
    }

    func channel(at indexPath: IndexPath) -> ChannelViewModel? {
        guard indexPath.section < self.viewModel.filteredChannels.count else {
            dlog(.tvGuide, "Index out of range: \(indexPath)")
            return nil
        }
        return self.viewModel.filteredChannels[indexPath.section]
    }

    func channels() -> [ChannelViewModel] {
        return viewModel.filteredChannels
    }

    func channels(at indexPaths: [IndexPath]) -> [ChannelViewModel] {
        indexPaths.compactMap { self.channel(at: $0) }
    }

    func updateChannels(with channelsWithEvents: ChannelsWithEvents) {
        channelsWithEvents.channelsWithEvents.forEach { (cwe) in
            self.updateChannel(channelId: cwe.channelId, events: cwe.events)
        }
    }

    func updateChannel(channelId: String, events: [Event]) {
        guard let channel = self.channel(for: channelId) else {
            return
        }
        channel.insertEvents(with: events)
        channel.updateRecordingStatuses(with: self.recordingStatuses)
    }

    func search(query: String) {
        viewModel.search(query)
    }

    func add(channelList: ChannelList?) {
        viewModel.add(channelList)
    }

    func updateChannels() {
        viewModel.updateChannels()
    }

    func filterChannels() {
        viewModel.filterChannels()
    }

    func channel(for id: String) -> ChannelViewModel? {
        return viewModel.channel(id: id)
    }

    func section(for channel: Channel) -> Int {
        return viewModel.findIndex(for: channel)
    }
}

extension TVDataSource: INSElectronicProgramGuideLayoutDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case INSEPGLayoutElementKindSectionHeader:
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, for: indexPath) as SectionHeader
        case INSEPGLayoutElementKindHourHeader:
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, for: indexPath) as HourHeader
        case INSEPGLayoutElementKindHalfHourHeader:
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, for: indexPath) as HourHeader
        case INSEPGLayoutElementKindCurrentTimeIndicator:
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, for: indexPath) as CurrentTimeIndicator
        default:
            return .init()
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: EventCell = collectionView.dequeueReusableCell(for: indexPath)
        cell.isUserInteractionEnabled = true
        cell.tvGuideCoordinator = tvGuideCoordinator
        cell.tvViewController = tvGuideCoordinator?.tvViewController
        if let event = self.event(at: indexPath) {
            cell.isSelected = (tvGuideCoordinator?.tvViewController?.selectedEvent?.id ?? "") == event.id
            cell.configure(with: event)
        } else {
            dlog("event for indexPath: \(indexPath) not found.")
        }
        return cell
    }

    func event(at indexPath: IndexPath) -> EventViewModel? {
        return viewModel.channelEvent(at: indexPath)
    }

    func event(at indexPath: IndexPath, with event: Event) -> EventViewModel? {
        return viewModel.channelEvent(at: indexPath, with: event)
    }

    func currentTime(for collectionView: UICollectionView!,
                     layout collectionViewLayout: INSElectronicProgramGuideLayout!) -> Date! {
        return Date.timeCurrent
    }

    func collectionView(_ collectionView: UICollectionView!,
                        startTimeFor electronicProgramGuideLayout: INSElectronicProgramGuideLayout!) -> Date! {
        return DateController.tvGuideMinTime
    }

    func collectionView(_ collectionView: UICollectionView!,
                        endTimeForlayout electronicProgramGuideLayout: INSElectronicProgramGuideLayout!) -> Date! {
        return DateController.tvGuideMaxTime
    }

    func collectionView(_ collectionView: UICollectionView!,
                        layout electronicProgramGuideLayout: INSElectronicProgramGuideLayout!,
                        startTimeForItemAt indexPath: IndexPath!) -> Date! {
        return viewModel.channelEvent(at: indexPath)?.startsAt ?? DateController.prevDay
    }

    func collectionView(_ collectionView: UICollectionView!,
                        layout electronicProgramGuideLayout: INSElectronicProgramGuideLayout!,
                        endTimeForItemAt indexPath: IndexPath!) -> Date! {
        return viewModel.channelEvent(at: indexPath)?.endsAt ?? DateController.nextDay
    }

    func channelsCount() -> Int {
        return viewModel.channels.count
    }

}

extension TVDataSource: RowImageFetching {
    func fetchableImage(at indexPath: IndexPath) -> FetchableValue<UIImage>? {
        return imageLogo(at: indexPath)
    }

    func update(_ image: UIImage, at indexPath: IndexPath) {
        guard let channel = self.channel(at: indexPath) else { return }
        channel.image?.update(newValue: image)
    }
}

extension TVDataSource: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.filteredChannels.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return max(1, viewModel.filteredChannels[section].events.count)
    }
}

extension TVDataSource {
    func addRecordingsStatuses(statuses: [RecordingStatus]) {
        statuses.forEach { (status) in
            if let index = recordingStatusIndex(for: status) {
                guard recordingStatuses.count < index else { return }
                recordingStatuses[index] = status
            } else {
                recordingStatuses.append(status)
            }
            viewModel.addRecordingStatus(with: status)
        }
    }

    func recordingStatusIndex(for status: RecordingStatus) -> Int? {
        for (index, recStatus) in recordingStatuses.enumerated() {
            if status.eventId == recStatus.eventId {
                return index
            }
        }
        return nil
    }

    func indexPath(for event: Event) -> IndexPath? {
        guard let indexPath = self.viewModel.indexPath(for: event) else { return nil }
        return indexPath
    }

    func updateRecordingStatuses(statuses: [RecordingStatus]) {
        cleanRecordingStatuses()
        self.viewModel.channels.forEach { (chvm) in
            chvm.updateRecordingStatuses(with: statuses)
        }
    }

    func cleanRecordingStatuses() {
        self.viewModel.channels.forEach { (chvm) in
            for var event in chvm.events {
                event.recordingStatus = nil
            }
        }
    }
}
