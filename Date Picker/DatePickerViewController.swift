//
//  EPGDatePickerViewController.swift
//  tv-ios
//
//  Created by Erinson Villarroel on 13/08/2019.
//  Copyright © 2020 Nexora AG. All rights reserved.
//

import UIKit
import SwiftDate

final class DatePickerViewController: UIViewController {

    @IBOutlet private weak var picker: UIPickerView!
    @IBOutlet private weak var dataSelectionLabel: UILabel!
    var dateItems:[String] = Array()
    var dates: [Date] = Array()
    var currentDate: Date = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        picker.delegate = self
        picker.dataSource = self
        select(date: currentDate)
    }
}
extension DatePickerViewController {
    var selectedDate: Date {
        return date(for: picker.selectedRow(inComponent: 0))
    }
    var lowerBound: Int {
        return 7
    }

    var upperBound: Int {
        return 7
    }

    var day: Int {
        return DateInRegion(currentDate, region: .local).dateComponents.day ?? 0
    }
    
    func format(date: Date) -> String {
        let dateInRegion = DateInRegion(date, region: DateSettings.appRegion)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "eeee,dd.MMMM"
        dateFormatter.locale = DateSettings.appRegion.locale
        return dateFormatter.string(from: dateInRegion.date)
    }

    func date(for row: Int) -> Date {
        let date = Date.timeCurrent.dateByAdding(row - lowerBound, .day).date
        return date
    }

    func select(date: Date) {
        for index in 0 ... lowerBound + upperBound + 1 {
            let current = Date.timeCurrent.dateByAdding(index - lowerBound, .day).day
            if day == current {
                picker.selectRow(index, inComponent: 0, animated: false)
                break
            }
        }
    }

    func rangeDates() {
        let date = DateInRegion(Date(), region: DateSettings.appRegion)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "eeee,dd.MMMM"
        dateFormatter.locale = DateSettings.appRegion.locale
        for index in -7 ... 7 {
            let newdate = date + index.days
            let str = dateFormatter.string(from: newdate.date)
            dateItems.append(str)
            dates.append(newdate.date)
        }
    }
}

extension DatePickerViewController :UIPickerViewDelegate, UIPickerViewDataSource {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return upperBound + lowerBound + 1
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let dateForItem = DateInRegion(date(for: row), region: DateSettings.appRegion)
        if dateForItem.isToday {
            return NSLocalizedString("Heute", comment: "")
        } else if dateForItem.isTomorrow {
            return NSLocalizedString("Morgen", comment: "")
        }
        return format(date: date(for: row))
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) { }
}
