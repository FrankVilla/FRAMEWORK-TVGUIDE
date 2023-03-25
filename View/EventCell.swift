//
//  FloatingCell.swift
//  tv-ios
//
//  Created by Erinson Villarroel on 22/08/2019.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import UIKit
import Reusable
import SwiftDate

@IBDesignable
class EventCell: UICollectionViewCell, Reusable, NibLoadable, TVGuideCoordinated {
    var tvGuideCoordinator: TVGuideFlowCoordinator?
    var tvViewController: TVViewController?
    @IBOutlet weak var recordingStatusIcon: UIImageView!
    var eventActionGestureRecognizer: UITapGestureRecognizer!

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!

    var viewModel: EventViewModel? {
        didSet {
            self.updateCellUI()
        }
    }

    var isLive: Bool {
        let eventStart = DateInRegion(viewModel?.event.startDate ?? Date(), region: DateSettings.appRegion)
        let eventEnd = DateInRegion(viewModel?.event.endDate ?? Date(), region: DateSettings.appRegion)
        let now = DateInRegion(Date(), region: DateSettings.appRegion)
        return now.isInRange(date: eventStart, and: eventEnd)
    }

    override func prepareForReuse() {
        self.recordingStatusIcon.isHidden = true
        titleLabel.textColor = .clear
        titleLabel.backgroundColor = Asset.Colors.grayBaseScreen.color
        titleLabel.layer.cornerRadius = 5
        titleLabel.clipsToBounds = true
        dateLabel.textColor = .clear
        dateLabel.backgroundColor = Asset.Colors.tundoraScreen.color
        dateLabel.layer.cornerRadius = 5
        dateLabel.clipsToBounds = true
        backgroundColor = Asset.Colors.codGrayScreen.color
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.isUserInteractionEnabled = true
        layer.rasterizationScale = UIScreen.main.scale
        layer.shouldRasterize = true
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        contentView.translatesAutoresizingMaskIntoConstraints = false
        eventActionGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(eventCellTapped(_:)))
        eventActionGestureRecognizer.cancelsTouchesInView = false
        eventActionGestureRecognizer.numberOfTouchesRequired = 1
        eventActionGestureRecognizer.delegate = self
        self.addGestureRecognizer(eventActionGestureRecognizer)
    }

    @objc func eventCellTapped(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            dlog("#TVG# event cell tapped: \(Date())")
            dlog("#TVG# event title: \(self.eventSection.title)")
            dlog("#TVG# event details view model: \(self.viewModel!.event)")
            guard let tvController = tvViewController else {
                dlog("TVViewController not set for the EventCell")
                return
            }
            tvViewController?.selectedEvent = viewModel?.event
            tvViewController?.selectedDetailEvent = viewModel?.event
            tvViewController?.selectedChannel = viewModel?.channel
            tvGuideCoordinator?.tvGuideViewControllerDidSelectEvent(tvController)
        }
    }

    private func setupDetailPageViewController() -> UIViewController? {
                let storyboard = UIStoryboard(name: "DetailPage", bundle: Bundle.main)
        let detailPageVC = storyboard.instantiateViewController(withIdentifier: "DetailPage")
                guard let navController = detailPageVC as? DetailPageNavigationController else {
                    dlog("detail page container view controller not fouund.")
                    return nil
                }
                guard let detailPageContainerVC = navController.topViewController as? DetailPageContainerViewController else {
                    dlog("detail page container view controller not found. ")
                    return nil
                }
                detailPageContainerVC.selectedEvent = self.viewModel?.event               
        return detailPageVC
    }

    var eventSection = ChannelCell.ChannelViewModel.EventSection() {
        didSet {
            do {
                setNeedsLayout()
            }
            titleLabel.text = eventSection.title
            titleLabel.backgroundColor = .clear
            dateLabel.text = timeframe
            dateLabel.backgroundColor = .clear
            titleLabel.textColor = isSelected ? .white : isFuture ? Asset.Colors.grayTextScreen.color : .white
            dateLabel.textColor = isSelected ? .white : Asset.Colors.grayTextScreen.color
            backgroundColor = isSelected ? Asset.Colors.redBase.color :
                isNow ? Asset.Colors.tundoraScreen.color : Asset.Colors.codGrayScreen.color
        }
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
    }

    func updateCellUI() {
        if viewModel?.recordingStatus != nil {
            updateRecordingStatus()
        }
    }

    func updateRecordingStatus() {
        if viewModel?.recordingStatus != nil {
            recordingStatusIcon.isHidden = false
        }
        dlog("#TVG# Update Recording status")
    }

}

extension EventCell {
    var isNow: Bool {
        return eventSection.startDate...eventSection.endDate ~= .timeCurrent
    }
    var isFuture: Bool {
        return eventSection.startDate.isAfter(date: .timeCurrent)
    }
    var timeframe: String {
        return "\(eventSection.startDate.toShortFormatTime())–\(eventSection.endDate.toShortFormatTime())"
    }
}

struct EventCellLayoutSettings {
    //updateColor
    //updateProgressBar
    //updateRecordingStatus
}

extension EventCell: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        dlog("received long press")
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - CellConfigurable
extension EventCell {
    func configure(with event: EventViewModel) {
        self.viewModel = event
        eventSection = ChannelCell.ChannelViewModel.EventSection(event: event.event)
    }
}

/*extension EventCell {
    struct ChannelViewModel {
        struct EventSection: EventInfo, RecordingStatusImaged {
            static let placeholder = "Laden..."
            static let noEventMessage = "Keine Informationen verfügbar"
            static let widthConstraint: CGFloat = 30.0
            static let rightConstraint: CGFloat = 8.0
            var isAvailable = true
            var title = ""
            var subtitle = ""
            var seasonNumber: Int?
            var episodeNumber: Int?
            var duration = 0
            var startDate = Date()
            var endDate = Date()
            var recordingStatus: RecordingStatus = RecordingStatus()
            var progress: Double {
                return calculateProgress()
            }
            var type: LiveTvViewController.RowType = .current
            var titleText: String {
                let description = isAvailable ? title : EventSection.noEventMessage
                return title.isEmpty ? EventSection.placeholder : description
            }
            var durationTimeText: String {
                guard duration > 0 else { return "" }

                var durationText = "\(duration.toMinutes()) Min."
                if type == .next {
                    let minutes = startDate.toMinutesSinceCurrentTime()
                    durationText = "in \(minutes) Min."
                }
                
                return durationText + timeText
            }
        }
        
        struct Layout {
            var titleColor: UIColor = .white
            var backgroundColor: UIColor = .grayBaseScreenColor
            var isProgressDisplayed: Bool = true
            var selectionEnabled: Bool = true
        }
        var logo = UIImage()
        var name = ""
    }
}

private extension EventCell.ChannelViewModel.EventSection {
    private func calculateProgress() -> Double {
        let elapsedTime = Date().timeIntervalSince(startDate)
        let totalTime = endDate.timeIntervalSince(startDate)
        return elapsedTime / totalTime
    }
}
*/
