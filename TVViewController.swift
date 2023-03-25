//
//  TVViewController.swift
//  tv-ios
//
//  Created by Milosz Milewski on 06/02/2020.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import UIKit
import INSElectronicProgramGuideLayout
import PureLayout
import SwiftDate

//input vector for initial state of
struct TVGuideInput {
    let currentTime: Date
    let initialVisibleTimeRange: DateRange
    let totalVisibleTimeRange: DateRange
}

struct TVGuideUpdateInput {
    let indexSetToReload: IndexSet
    let dateRangeToReload: DateRange
}

extension UICollectionView {
    var epgLayout: INSElectronicProgramGuideLayout? {
        return collectionViewLayout as? INSElectronicProgramGuideLayout
    }
}

final class TVViewController: UIViewController, Networked, MainCoordinated, Recorded, TVGuideCoordinated {
    let networkIdentifier = NetworkIdentifier()

    // MARK: Parameters
    enum LayoutParameters {
        static let sectionHeaderHeight: CGFloat = 60.0
        static let sectionHeaderWidth: CGFloat = 90.0
        static let channelLayoutMargin: CGFloat = 1.0
        static let timeBarHeight: CGFloat = 40.0
        static let hourWidth: CGFloat = 400.0
        static let minLength = 13

        static func hourWidth(scale: CGFloat) -> CGFloat {
            return hourWidth * scale
        }
    }

    var networkController: NetworkController?
    var mainCoordinator: MainFlowCoordinator?
    var recordingController: RecordingController?
    var tvGuideCoordinator: TVGuideFlowCoordinator?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    fileprivate var dataSource: TVDataSource? {
        didSet {
            self.searchButton.isUserInteractionEnabled = self.dataSource != nil
        }
    }
    var visibleIndexSet: IndexSet = IndexSet()
    var scaleFactor: CGFloat = 1.0
    var offset: CGPoint = .zero
    let currentTime = Date.timeCurrent
    let primeTime = DateController.primeTime
    var selectionTime = Date.timeCurrent
    let maxTime = DateController.tvGuideMaxTime
    let minTime = DateController.tvGuideMinTime
    var leftMarkTime = Date.timeCurrent
    var rightMarkTime = DateController.primeTime
    var viewCenterTime = Date.timeCurrent.dateByAdding(1, .hour).date
    var selectedEvent: Event? {
        didSet {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    var selectedChannel: Channel?
    var selectedDetailEvent: Event?

    var eventDidUpdate: ((Event?) -> Void)?

    @IBOutlet private weak var datePickerButton: UIButton!
    @IBOutlet private weak var leftMarkButton: UIButton! {
        didSet {
            leftMarkButton.layer.cornerRadius = 2
            leftMarkButton.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
    }
    @IBOutlet private weak var rightMarkButton: UIButton! {
        didSet {
            rightMarkButton.layer.cornerRadius = 2
            rightMarkButton.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        }
    }

    @IBOutlet private weak var rightMarkView: RightTriangleView!
    @IBOutlet private weak var leftMarkView: LeftTriangleView!

    @IBOutlet private weak var collectionView: UICollectionView! {
        didSet {
            collectionView.register(cellType: EventCell.self)
            collectionView.register(supplementaryViewType: CurrentTimeIndicator.self,
                                    ofKind: INSEPGLayoutElementKindCurrentTimeIndicator)
            collectionView.register(supplementaryViewType: HourHeader.self,
                                    ofKind: INSEPGLayoutElementKindHourHeader)
            collectionView.register(supplementaryViewType: HourHeader.self,
                                    ofKind: INSEPGLayoutElementKindHalfHourHeader)
            collectionView.register(supplementaryViewType: SectionHeader.self,
                                    ofKind: INSEPGLayoutElementKindSectionHeader)
        }
    }

    @IBOutlet weak var searchStackView: UIStackView!
    @IBOutlet weak var searchStackConstraintHeight: NSLayoutConstraint!
    @IBOutlet weak var searchBar: UISearchBar! {
        didSet {
            searchBar.delegate = self
            searchBar.showsCancelButton = true
        }
    }
    @IBOutlet weak var searchButton: StyledButton! {
        didSet { self.searchButton.isUserInteractionEnabled = false }
    }
    @IBOutlet weak var channelListButton: StyledButton!

    @IBOutlet weak var selectionView: UIView!
    @IBOutlet weak var selectionViewContraintHeight: NSLayoutConstraint!

    @IBOutlet private weak var layout: INSElectronicProgramGuideLayout! {
        didSet {
            layout?.register(CurrentTimeGridlineView.self,
                             forDecorationViewOfKind: INSEPGLayoutElementKindCurrentTimeIndicatorVerticalGridline)
            layout?.register(GridlineView.self,
                             forDecorationViewOfKind: INSEPGLayoutElementKindVerticalGridline)
            layout?.register(HalfHourLineView.self,
                             forDecorationViewOfKind: INSEPGLayoutElementKindHalfHourVerticalGridline)
            layout?.register(HeaderBackgroundView.self,
                             forDecorationViewOfKind: INSEPGLayoutElementKindSectionHeaderBackground)
            layout?.register(HourHeaderBackgroundView.self,
                             forDecorationViewOfKind: INSEPGLayoutElementKindHourHeaderBackground)

            configureLayout()
        }
    }

    override func unwind(for unwindSegue: UIStoryboardSegue, towards subsequentVC: UIViewController) {
        dlog(.tvGuide, "Unwinding")
    }

    private func configureLayout() {
        layout?.shouldResizeStickyHeaders = true
        layout?.shouldUseFloatingItemOverlay = true
        layout?.currentTimeVerticalGridlineWidth = LayoutParameters.channelLayoutMargin
        layout?.hourHeaderHeight = LayoutParameters.timeBarHeight
        layout?.hourWidth = LayoutParameters.hourWidth(scale: scaleFactor)
        layout?.sectionHeight = LayoutParameters.sectionHeaderHeight
        layout?.sectionHeaderWidth = LayoutParameters.sectionHeaderWidth
        layout?.cellMargin = UIEdgeInsets(top: 0,
                                          left: 0,
                                          bottom: LayoutParameters.channelLayoutMargin,
                                          right: LayoutParameters.channelLayoutMargin)
        layout?.sectionGap = 0
        layout?.currentTimeIndicatorSize = .init(width: 56, height: 40)
        layout?.currentTimeIndicatorShouldBeBehind = false
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        mainCoordinator?.configure(viewController: segue.destination)
        segue.forward(event: selectedEvent)
        segue.forward(channel: selectedChannel)

        if let navigationController = segue.destination as? DetailPageNavigationController,
            let viewController = navigationController.topViewController as? DetailPageContainerViewController {
            viewController.networkController = self.networkController
            viewController.delegate = self
        }

        if let navigationController = segue.destination as? UINavigationController,
            let datePickerViewController = navigationController.viewControllers.first as? DatePickerViewController {
            datePickerViewController.currentDate = self.date
        }

        (segue.destination as? ChannelListsViewController)?.delegate = self
        segue.setDelegate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.startActivityIndicator()
        if let viewController = mainCoordinator?.mainTabBarController.viewControllers?.first?.children.first as? LiveTvViewController {
            selectedChannel = viewController.selectedChannel
        }
        let input = configureInputState()
        configureDataSource(with: input)
        configureObservers()
    }

    @IBAction func toggleSearch(_ sender: UIButton) {
        showSearchBar()
    }

    @IBAction func showChannelList(_ sender: UIButton) {
        hideSearchBar()
        tvGuideCoordinator?.tvGuideViewControllerDidShowChannelList(self)
    }

    func configureInputState() -> TVGuideInput {
        var input: TVGuideInput
        let currentDate = Date.timeCurrent
        let initialTimeRange = DateController.calculateEpgFetchDate(for: currentDate)
        dlog(.tvGuide, "CurrentDate: \(currentDate)")
        dlog(.tvGuide, "InitialTimeRange: \(initialTimeRange)")
        let maxTimeRange = DateController.calculateEpgFetchDate(for: currentDate)
        input = TVGuideInput(currentTime: currentDate,
                             initialVisibleTimeRange: initialTimeRange,
                             totalVisibleTimeRange: maxTimeRange)
        return input
    }

    func configureDataSource(with input: TVGuideInput) {
        let dispatchGroup = DispatchGroup()
        DispatchQueue.global(qos: .default).async {
            dispatchGroup.enter()
            self.calculateIndexSet(for: Float(LayoutParameters.sectionHeaderHeight)) { (indexSet) in
                self.visibleIndexSet = indexSet
                dispatchGroup.leave()
            }
            dispatchGroup.wait()
            dispatchGroup.enter()
            self.fetchChannels(with: { (channels) in
                DispatchQueue.main.async {
                    self.dataSource = TVDataSource.init(with: channels, date: self.date)
                    self.dataSource?.tvGuideCoordinator = self.tvGuideCoordinator
                    self.dataSource?.tvGuideCoordinator?.tvViewController = self
                    self.dataSource?.networkController = self.networkController
                    dispatchGroup.leave()
                }
            }, onError: { (error) in
                dlog(.tvGuide, "Error fetching channels: \(error)")
                dispatchGroup.leave()
            })
            dispatchGroup.wait()
            if self.selectedChannel != nil, let selectedChannelSection = self.dataSource?.section(for: self.selectedChannel!), !self.visibleIndexSet.contains(selectedChannelSection) {
                self.visibleIndexSet = self.recalculateInitialIndexSet(with: selectedChannelSection)
            }
            dispatchGroup.enter()
            self.fetchChannelEventsForVisibleTimeRange(with: self.visibleIndexSet,
                                                       timeRange: input.initialVisibleTimeRange) { [weak self] (channelsWithEvents) in
                                                        dlog(.tvGuide, "Fetching channels for time range: \(input.initialVisibleTimeRange)")
                                                        let strongSelf = self
                                                        if channelsWithEvents != nil {
                                                            strongSelf?.dataSource?.updateChannels(with: channelsWithEvents!)
                                                        } else {
                                                            dlog(.tvGuide, "No events for channels fetched")
                                                        }
                                                        dispatchGroup.leave()
            }
            dispatchGroup.enter()
            self.fetchRecordingStatus { (_) in
                dispatchGroup.leave()
            }
            dispatchGroup.enter()
            self.fetchChannelLists {
                dispatchGroup.leave()
            }
            dispatchGroup.wait()
            DispatchQueue.main.async {
                self.collectionView.dataSource = self.dataSource
                self.layout.dataSource = self.dataSource
                self.layout.delegate = self
                self.stopActivityIndicator()
                self.collectionView.reloadData()
                self.layout.invalidateLayoutCache()
                self.configureUI()
                self.collectionView.performBatchUpdates(nil, completion: { _ in
                    self.collectionView.reloadData()
                    self.scroll(toDate: self.currentTime.dateByAdding(-30, .minute).date, updateData: false)
                    self.scroll(to: self.selectedChannel)
                    self.updateDataSourceAfterScroll()
                    self.collectionView.backgroundColor = Asset.Colors.grayLightScreen.color
                })
            }
        }
    }

    func recalculateInitialIndexSet(with section: Int) -> IndexSet {
        var rangeToReload: IndexSet = IndexSet()
        let startIndex: Int = section - self.visibleIndexSet.count/2
        let endIndex: Int = section + self.visibleIndexSet.count/2
        for index in startIndex..<endIndex {
            rangeToReload.insert(index)
        }
        return rangeToReload
    }

    func configureObservers() {
        recordingController?.results.addObserver(self, options: [.initial, .new]) { [weak self] (results, _) in
            dlog(.tvGuide, "Observable TVGuide result: \(results)")
            guard let strongSelf = self else { return }
            strongSelf.dataSource?.addRecordingsStatuses(statuses: results)
            //strongSelf.dataSource?.filterEvents()
            //strongSelf.passEventData(forIndexPath: strongSelf.selectedChannelRow.index)
            DispatchQueue.main.async {
                strongSelf.collectionView.reloadData()
            }
        }
    }

    func startActivityIndicator() {
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
    }

    func stopActivityIndicator() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
    }

    func fetchChannels(with completion: @escaping (_ channels: [Channel]) -> Void,
                       onError: @escaping (_ error: Error) -> Void) {
        self.networkController?.fetchChannels(withIdentifier: self.networkIdentifier,
                                         completion: completion,
                                         onError: onError)
    }

    func fetchChannelLogosForRows(with indexSet: IndexSet, completion: @escaping () -> Void) {
        let indexPaths = indexSet.map { (section) -> IndexPath in
            return IndexPath(row: 0, section: section)
        }
        guard let channels = self.dataSource?.channels(at: indexPaths) else {
            completion()
            return
        }
        DispatchQueue.global(qos: .default).async {
            let dispatchGroup = DispatchGroup()
            for index in 0..<channels.count {
                if (channels[index].image?.fetchedValue) == nil {
                    dispatchGroup.enter()
                    guard let imageUrl = channels[index].image?.url else {
                        dlog(.tvGuide, "Url not valid")
                        dispatchGroup.leave()
                        return
                    }
                    self.networkController?.fetchCachableImage(withIdentifier: self.networkIdentifier,
                                                               for: imageUrl,
                                                               completion: { (result) in
                                                                do {
                                                                    let image = try result.get()
                                                                    channels[index].image?.update(newValue: image)
                                                                    dispatchGroup.leave()
                                                                } catch {
                                                                    dlog(.tvGuide, error)
                                                                    dispatchGroup.leave()
                                                                }
                    })
                }
            }
            dispatchGroup.wait()
            completion()
        }
    }

    func fetchChannelEventsForVisibleTimeRange(with indexSet: IndexSet,
                                               timeRange: DateRange,
                                               completion: @escaping (_ events: ChannelsWithEvents?) -> Void) {
        let indexPaths = indexSet.map { (section) -> IndexPath in
            return IndexPath(row: 0, section: section)
        }
        guard let channels = self.dataSource?.channels(at: indexPaths) else {
            completion(nil)
            return
        }
        networkController?.fetchChannelsEvents(withIdentifier: self.networkIdentifier,
                                               for: channels,
                                               dateRange: timeRange,
                                               with: { (channelsWithEvents) in
                                                completion(channelsWithEvents)
        })
    }

    func fetchRecordingStatus(with completion: @escaping (_ error: Error?) -> Void) {
        recordingController?.fetchRecordingStatus(with: { (result) in
            completion(result)
        })
    }

    func fetchChannelLists(with completion: @escaping () -> Void) {
        fetchChannelLists { [weak self] result in
            guard let strongSelf = self else { return }
            do {
                let channelLists = try result.get()
                guard let channelListId = UserDefaults.standard.object(forKey: strongSelf.channelListKey) as? String else {
                    UserDefaults.standard.setValue("-1", forKey: strongSelf.channelListKey)
                    strongSelf.dataSource?.updateChannels()
                    return
                }
                let channelList = channelLists.channelList.first(where: { $0.id == channelListId })
                strongSelf.dataSource?.add(channelList: channelList)
                strongSelf.dataSource?.filterChannels()
                strongSelf.updateDataSourceAfterScroll()
                DispatchQueue.main.async {
                    strongSelf.channelListButton.setTitle(channelList?.name ?? "Alle Sender", for: .normal)
                }
            } catch {
                strongSelf.dataSource?.updateChannels()
                strongSelf.updateDataSourceAfterScroll()
            }
            completion()
        }
    }

    func calculateIndexSet(for cellHeight: Float, with completion: @escaping (_ indexSet: IndexSet) -> Void) {
        DispatchQueue.main.async {
            var rangeToReload: IndexSet = IndexSet()
            let minY = Float(self.collectionView.bounds.origin.y)
            let maxY = Float(self.collectionView.bounds.origin.y + self.collectionView.frame.height)
            let minYIndex = (Int(minY/cellHeight) == 0) ? 0 : Int(minY/cellHeight) - 1
            let maxYIndex = (Int(maxY/cellHeight) > self.collectionView.numberOfSections) ? Int(maxY/cellHeight) : Int(maxY/cellHeight) + 1
            for index in minYIndex..<maxYIndex+1 {
                rangeToReload.insert(index)
            }
            completion(rangeToReload)
        }
    }

    private func configureUI() {
        let centerDate = Date()
        setupScrollView()
        updateDate(centerDate)
        if let channel = selectedChannel {
            self.scroll(to: channel)
        }
        updateMarks()
    }

    private func setupScrollView() {
        self.collectionView.decelerationRate = .fast
    }

    private func setupDatePickerButton(_ date: Date) {
        if let dateString = layout?.dateString(date) {
            datePickerButton.setTitle(dateString, for: .normal)
            datePickerButton.isHidden = false
        }
    }

    func updateDate(_ date: Date) {
        dlog(.tvGuide, "\(date)")
        selectionTime = date
        setupDatePickerButton(date)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        networkController?.resume(with: self.networkIdentifier)

        if let viewController = mainCoordinator?.mainTabBarController.viewControllers?.first?.children.first as? LiveTvViewController {
            selectedChannel = viewController.selectedChannel
        }

        guard self.dataSource != nil, let channel = self.selectedChannel else {
            return
        }

        fetchChannelLists { [weak self] in
            self?.updateDataSourceAfterScroll()
        }

        scroll(to: channel)
        scroll(toDate: .timeCurrent, updateData: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        networkController?.suspend(with: self.networkIdentifier)
    }

    @IBAction func dateDidSelect(segue: UIStoryboardSegue) {
        if let pickerViewController: DatePickerViewController = segue.source as? DatePickerViewController {
            let date = self.date
            let millis = date.toMillis() - date.dateAtStartOf(.day).date.toMillis()
            let selectedDate = pickerViewController.selectedDate.dateAtStartOf(.day).date
            self.selectionTime = selectedDate.add(milliseconds: millis)
            if selectionTime > maxTime {
                selectionTime = maxTime
            }
            if selectionTime < minTime {
                selectionTime = minTime
            }
            scroll(toDate: selectionTime,
                   offset: LayoutParameters.sectionHeaderWidth,
                   animated: true,
                   updateData: false)
        }
    }

    @IBAction private func changeScale(_ sender: UIPinchGestureRecognizer) {
        scaleFactor *= sender.scale
        scaleFactor = max(1.0, min(scaleFactor, 2))

        if sender.state == UIGestureRecognizer.State.began {
            viewCenterTime = layout?.date(forXCoordinate: collectionView.contentOffset.x) ?? Date()
        }

        layout?.hourWidth = LayoutParameters.hourWidth(scale: scaleFactor)
        layout?.invalidateLayoutCache()

        scroll(toDate: viewCenterTime, offset: collectionView.frame.width / 4, animated: false, updateData: false)
        collectionView.reloadData()
    }

}

extension TVViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        willDisplaySupplementaryView view: UICollectionReusableView,
                        forElementKind elementKind: String,
                        at indexPath: IndexPath) {
        switch view {
        case let channelHeader as SectionHeader:
            channelHeader.backgroundColor = Asset.Colors.codGrayScreen.color
            fetchImageForRow(at: indexPath)
        case let hourHeader as HourHeader where elementKind == INSEPGLayoutElementKindHourHeader:
            if let date = collectionView.epgLayout?.dateForHourHeader(at: indexPath) {
                hourHeader.setTime(date)
            }
        case let hourHeader as HourHeader where elementKind == INSEPGLayoutElementKindHalfHourHeader:
            if let date = collectionView.epgLayout?.dateForHalfHourHeader(at: indexPath) {
                hourHeader.setTime(date)
            }
        default: break
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        didEndDisplayingSupplementaryView view: UICollectionReusableView,
                        forElementOfKind elementKind: String, at indexPath: IndexPath) {
    }

}

extension TVViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        dataSource?.search(query: text)
        dataSource?.filterChannels()
        updateDataSourceAfterScroll()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        hideSearchBar()
    }

    private func showSearchBar() {
        selectionViewContraintHeight.constant = 0
        searchStackConstraintHeight.constant = 40

        searchStackView.isHidden = false
        searchBar.becomeFirstResponder()

        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            self.selectionView.alpha = 0
            self.searchStackView.alpha = 1
            self.view.layoutIfNeeded()
        })
    }

    @objc private func hideSearchBar() {
        selectionViewContraintHeight.constant = 40
        searchStackConstraintHeight.constant = 0
        searchStackView.isHidden = true

        searchBar.resignFirstResponder()
        searchBar.text = ""
        dataSource?.search(query: "")
        dataSource?.filterChannels()
        updateDataSourceAfterScroll()

        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            self.selectionView.alpha = 1
            self.searchStackView.alpha = 0.0
            self.view.layoutIfNeeded()
        })
    }
}

extension TVViewController: INSElectronicProgramGuideLayoutDelegate {

    func collectionView(_ collectionView: UICollectionView!,
                        layout electronicProgramGuideLayout: INSElectronicProgramGuideLayout!,
                        sizeForFloatingItemOverlayAt indexPath: IndexPath!) -> CGSize {
        let count = max(dataSource?.event(at: indexPath)?.title.count ?? 0, LayoutParameters.minLength)
        let text = String(repeating: "0", count: count)
        let width = text.size(withAttributes: [.font: UIFont.systemFont(ofSize: 20)]).width
        return CGSize(width: width, height: LayoutParameters.sectionHeaderHeight)

    }

}

extension TVViewController: RowImageFetching {
    func fetchableImage(at indexPath: IndexPath) -> FetchableValue<UIImage>? {
        return dataSource?.channel(at: indexPath)?.image
    }

    func update(_ image: UIImage, at indexPath: IndexPath) {
        guard let sectionHeader = collectionView.supplementaryView(
            forElementKind: INSEPGLayoutElementKindSectionHeader,
            at: indexPath) as? SectionHeader else {
                return
        }
        sectionHeader.update(image)
    }
}

// MARK: -
extension TVViewController: ChannelListsFetching {
    var channelListKey: String {
        return "\(String(describing: ChannelList.self))-\(networkController!.profileId!)"
    }
}

extension TVViewController: SelectChannelListDelegate {
    func selectChannelList(channelList: ChannelList?) {
        guard let channelListId = channelList?.id else {
            UserDefaults.standard.removeObject(forKey: channelListKey)
            dataSource?.filterChannels()
            updateDataSourceAfterScroll()
            return
        }
        UserDefaults.standard.set(channelListId, forKey: channelListKey)
        channelListButton.setTitle(channelList?.name ?? "Alle Sender", for: .normal)
        dataSource?.add(channelList: channelList)
        dataSource?.filterChannels()
        updateDataSourceAfterScroll()
    }
}

// MARK: - TVViewController Scrolling
extension TVViewController {

    var date: Date {
        return layout?.date(forXCoordinate: collectionView.contentOffset.x) ?? Date.timeCurrent
    }

    @IBAction func scrollLeft(_ sender: UIButton) {
        scroll(toDate: leftMarkTime, offset: collectionView.frame.width / 4, updateData: true)
    }

    @IBAction func scrollRight(_ sender: UIButton) {
        scroll(toDate: rightMarkTime, offset: collectionView.frame.width / 4, updateData: true)
    }

    private func scroll(toDate date: Date, offset: CGFloat = 0.0, animated: Bool = false, updateData: Bool) {
        self.dataSource?.date = date
        layout?.scroll(date: date, offset: offset, animated: animated)
        if updateData { self.updateDataSourceAfterScroll() }
    }

    private func scroll(to channel: Channel?, animated: Bool = false) {
        guard let channel = channel, let section = dataSource?.section(for: channel) else {
            return
        }
        let positionY = CGFloat(section) * LayoutParameters.sectionHeaderHeight
        offset = collectionView.contentOffset
        layout.scroll(positionY: positionY, offset: 0, animated: animated)
    }

    private func findIndexPath(for channel: Channel) -> IndexPath? {
        guard let section = dataSource?.section(for: channel) else {
            return nil
        }
        return IndexPath(item: 0, section: section)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let deltaX = abs(self.offset.x - self.collectionView.contentOffset.x)
        let deltaY = abs(self.offset.y - self.collectionView.contentOffset.y)
        if deltaX > 0 && deltaY > 0 {
            if deltaX > deltaY {
                self.collectionView.contentOffset = CGPoint(x: self.collectionView.contentOffset.x, y: self.offset.y)
            } else {
                self.collectionView.contentOffset = CGPoint(x: self.offset.x, y: self.collectionView.contentOffset.y)
            }
        }

        updateDate(date)
        updateMarks()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.offset = scrollView.contentOffset
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        perform(#selector(self.updateDataSourceAfterScroll), with: nil, afterDelay: Double(velocity.y))
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        perform(#selector(self.updateDataSourceAfterScroll), with: nil, afterDelay: 0.05)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        perform(#selector(self.updateDataSourceAfterScroll), with: nil, afterDelay: 0.05)
    }

    @objc func updateDataSourceAfterScroll() {
        guard dataSource != nil else { return }
        DispatchQueue.main.async {
            self.selectionTime = self.date
        }
        DispatchQueue.global(qos: .userInteractive).async {
            let dispatchGroup = DispatchGroup()
            self.getInputForDataSourceRefresh { (input) in
                dispatchGroup.enter()
                //update events
                self.fetchChannelEventsForVisibleTimeRange(with: input.indexSetToReload,
                                                           timeRange: input.dateRangeToReload) { [weak self] (channelsWithEvents) in
                                                            let strongSelf = self
                                                            if channelsWithEvents != nil {
                                                                strongSelf?.dataSource?.updateChannels(with: channelsWithEvents!)
                                                            } else {
                                                                dlog(.tvGuide, "No events for channels fetched")
                                                            }
                                                            dispatchGroup.leave()
                }
                dispatchGroup.wait()
                //reload collection view
                DispatchQueue.main.async {
                    self.stopActivityIndicator()
                    self.collectionView.reloadData()
                    self.collectionView.epgLayout?.invalidateLayoutCache()
                    self.layout.invalidateLayoutCache()
                    self.updateDate(self.selectionTime)
                    self.updateMarks()
                }
            }
        }
    }

    func getInputForDataSourceRefresh(with completion: @escaping (_ input: TVGuideUpdateInput) -> Void ) {
        let range = DateController.calculateEpgRangeDates(for: selectionTime)
        dlog(.tvGuide, "Range: \(range)")
        var updateInput: TVGuideUpdateInput = TVGuideUpdateInput(indexSetToReload: IndexSet(),
                                                                 dateRangeToReload: DateRange(start: range.start, end: range.end))
        DispatchQueue.global(qos: .userInteractive).async {
            let dg = DispatchGroup()
            var newIndexSet: IndexSet = IndexSet()
            var dateRangeToRefresh: DateRange = DateRange(start: Date(), end: Date())
            dg.enter()
            self.calculateIndexSet(for: Float(LayoutParameters.sectionHeaderHeight)) { (indexSet) in
                newIndexSet = indexSet
                dateRangeToRefresh = self.calculateDateRangeForEventsRefreshing(with: self.selectionTime)
                updateInput = TVGuideUpdateInput(indexSetToReload: newIndexSet, dateRangeToReload: dateRangeToRefresh)
                dg.leave()
            }
            dg.wait()
            completion(updateInput)
        }
    }

    func calculateIndexSetToRefresh(with indexSet: IndexSet) -> IndexSet {
        let delta = self.visibleIndexSet.first! > indexSet.first! ? self.visibleIndexSet.first! - indexSet.first! : indexSet.first! - self.visibleIndexSet.first!
        if delta / self.visibleIndexSet.count < 1 {
            let startIndex = self.visibleIndexSet.first! > indexSet.first! ? indexSet.first! : self.visibleIndexSet.first! + self.visibleIndexSet.count
            var indexSetToRefresh: IndexSet = IndexSet()
            for index in startIndex..<(startIndex+delta) {
                indexSetToRefresh.insert(index)
            }
            return indexSetToRefresh
        } else {
            return indexSet
        }
    }

    func calculateDateRangeForEventsRefreshing(with currentDate: Date) -> DateRange {
        return DateController.calculateEpgFetchDate(for: currentDate)
    }

    func updateMarks() {
        updateLeftJumpMark()
        updateRightJumpMark()
        updateCurrentTimeMark()
    }

    func updateLeftJumpMark() {
        guard let lowerDate = layout?.date(forXCoordinate: collectionView.contentOffset.x) else {
            return
        }

        leftMarkButton.isHidden = false
        leftMarkView.isHidden = false
        dlog(.tvGuide, "Left mark lowerDate: \(lowerDate)")

        switch lowerDate {
        case maxTime...:
            leftMarkButton.isHidden = true
            leftMarkView.isHidden = true
        case primeTime...:
            leftMarkButton.setTitle("20.15", for: .normal)
            leftMarkTime = primeTime
        case currentTime...:
            leftMarkButton.setTitle("JETZT", for: .normal)
            leftMarkTime = currentTime
        default:
            leftMarkButton.isHidden = true
            leftMarkView.isHidden = true
        }
    }

    func updateRightJumpMark() {
        guard let upperDate = layout?.date(forXCoordinate: collectionView.contentOffset.x + collectionView.frame.width) else {
            return
        }

        rightMarkButton.isHidden = false
        rightMarkView.isHidden = false
        dlog(.tvGuide, " Right mark upperDate \(upperDate)")

        switch upperDate {
        case ..<minTime:
            rightMarkButton.isHidden = true
            rightMarkView.isHidden = true
        case ..<currentTime:
            rightMarkButton.setTitle("JETZT", for: .normal)
            rightMarkTime = currentTime
        case ..<primeTime:
            rightMarkButton.setTitle("20.15", for: .normal)
            rightMarkTime = primeTime
        default:
            rightMarkButton.isHidden = true
            rightMarkView.isHidden = true
        }
    }

    func updateCurrentTimeMark() {
        if isCurrentTimeVisibleOnScreen() {
            layout.currentTimeIndicatorShouldBeBehind = false
        } else {
            layout.currentTimeIndicatorShouldBeBehind = true
        }
    }

    func isCurrentTimeVisibleOnScreen() -> Bool {
        guard let range = currentlyVisibleTimeRange() else {
            return false
        }
        return Date.timeCurrent.isInRange(date: range.start, and: range.end)
    }

    func currentlyVisibleTimeRange() -> DateRange? {
        guard let start = layout.date(forXCoordinate: collectionView.contentOffset.x) else { return nil }
        guard let end = layout.date(forXCoordinate: collectionView.contentOffset.x + collectionView.frame.width) else {
            return nil }
        let range = DateRange(start: start, end: end)
        return range
    }

    func updateVisibleRecordingsStatuses() {
        guard let recordingController = self.recordingController else { return }
        self.dataSource?.updateRecordingStatuses(statuses: recordingController.results.value)
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
}

extension TVViewController: DetailPageDelegate {

    func updateEvent() {
        guard let channel = selectedChannel,
            let selectedDetailEvent = selectedDetailEvent,
            let section = dataSource?.section(for: channel) else {
                return
        }
        guard let event = dataSource?.event(at: IndexPath(row: 0, section: section),
                                            with: selectedDetailEvent)?.event else {
            return
        }
        eventDidUpdate?(event)
    }

    func close() {
        self.fetchRecordingStatus { (error) in
            if error != nil {
                dlog(.tvGuide, "Fetching recordings finished with error: \(String(describing: error))")
            } else {
                self.updateVisibleRecordingsStatuses()
            }
        }
    }
}

extension TVViewController {
    private func refresh() {
        if let viewController = mainCoordinator?.mainTabBarController.viewControllers?.first?.children.first as? LiveTvViewController {
            selectedChannel = viewController.selectedChannel
        }

        guard self.dataSource != nil, let channel = self.selectedChannel else {
            return
        }

        fetchChannelLists { [weak self] in
            self?.updateDataSourceAfterScroll()
        }

        scroll(to: channel)
    }
}
