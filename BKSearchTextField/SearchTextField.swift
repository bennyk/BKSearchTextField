//
//  SearchTextField.swift
//  SearchTextField
//
//  Created by Benny Khoo on 12/27/16.
//  Copyright © 2016 Benny Khoo. All rights reserved.
//

import Cocoa

open class SearchTextField: NSTextField {

    ////////////////////////////////////////////////////////////////////////
    // Public interface
    
    /// Maximum number of results to be shown in the suggestions list
    open var maxNumberOfResults = 0

    /// Maximum height of the results list
    open var maxResultsListHeight = 0
    
    /// Indicate if this field has been interacted with yet
    open var interactedWith = false

    /// Set your custom visual theme, or just choose between pre-defined SearchTextFieldTheme.lightTheme() and SearchTextFieldTheme.darkTheme() themes
    open var theme = SearchTextFieldTheme.lightTheme() {
        didSet {
            tableView?.reloadData()
        }
    }
    
    /// Show the suggestions list without filter when the text field is focused
    open var startVisible = false
    
    /// Set an array of SearchTextFieldItem's to be used for suggestions
    open func filterItems(_ items: [SearchTextFieldItem]) {
        filterDataSource = items
    }

    /// Set an array of strings to be used for suggestions
    open func filterStrings(_ strings: [String]) {
        var items = [SearchTextFieldItem]()
        
        for value in strings {
            items.append(SearchTextFieldItem(title: value))
        }
        
        filterDataSource = items
    }
    
    /// Closure to handle when the user pick an item
    open var itemSelectionHandler: SearchTextFieldItemHandler?
    
    /// Closure to handle when the user stops typing
    open var userStoppedTypingHandler: ((Void) -> Void)?
    
    /// Set your custom set of attributes in order to highlight the string found in each item
    open var highlightAttributes: [String: AnyObject] = [NSFontAttributeName:NSFont.boldSystemFont(ofSize: 13),
                                                         NSUnderlineStyleAttributeName:1 as AnyObject]
    
    open func showLoadingIndicator() {
        indicator.startAnimation(self)
    }

    open func stopLoadingIndicator() {
        indicator.stopAnimation(self)
    }
    
    var fieldEditor: NSText? {
        get {
            return self.window?.fieldEditor(true, for: self)
        }
    }
    
    var searchableStringValue: String {
        get {
            if !stringValue.isEmpty {
                if let range = self.fieldEditor?.selectedRange {
//                    Swift.print(range.location, range.length)
                    let prefix = stringValue.substring(with: 0..<range.location)
                    return prefix
                }
            }
            return self.stringValue
        }
    }
    
    var prevLength = 0
    var allowClearField = true
    

    ////////////////////////////////////////////////////////////////////////
    // Private implementation
    
    fileprivate var tableView: SearchTextFieldTableView?
    fileprivate var tableContainer: NSScrollView?
    fileprivate var shadowView: NSView?
    fileprivate var fontConversionRate: CGFloat = 0.7
    fileprivate var timer: Timer? = nil
    fileprivate static let cellIdentifier = "APSearchTextFieldCell"
    fileprivate var indicator = NSProgressIndicator(frame:CGRect(x: 0, y: 0, width: 16, height: 16))
    
    
    fileprivate var filteredResults = [SearchTextFieldItem]()
    fileprivate var filterDataSource = [SearchTextFieldItem]() {
        didSet {
            filter(false)
            redrawSearchTableView()
        }
    }
    
    fileprivate var currentInlineItem = ""

    override open func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
    }
    
    override open func layout() {
        super.layout()
        
        // delegate for arrow key callbacks
        self.delegate = self
        
        buildSearchTableView()
        
        // Create the loading indicator
        if indicator.superview == nil {
            indicator.controlSize = NSControlSize.small
            indicator.isDisplayedWhenStopped = false
            indicator.style = .spinningStyle
            indicator.isIndeterminate = true
            
            superview?.addSubview(indicator)
            var origin = self.convert(NSPoint.zero, to: self.superview)
            origin.y = origin.y - self.frame.height + self.frame.height/2 - indicator.frame.height/2
            origin.x += self.frame.width - indicator.frame.width - 3
            indicator.setFrameOrigin(origin)
        }
    }
    
    // Create the filter table and shadow view
    fileprivate func buildSearchTableView() {
        if let tableContainer = tableContainer, let tableView = tableView, let shadowView = shadowView {
            tableView.rowHeight = theme.cellHeight
            tableView.backgroundColor = NSColor.white
            tableView.headerView = nil
            tableView.rowHeight = 22
//            tableView.usesAlternatingRowBackgroundColors = true
            tableView.allowsMultipleSelection = false
            
//            tableView.masksToBounds = true
//            tableView.borderWidth = 0.5
            tableView.dataSource = self
            tableView.delegate = self
//            tableView.separatorInset = UIEdgeInsets.zero
            
            shadowView.wantsLayer = true
            shadowView.shadow = NSShadow()
            shadowView.layer?.backgroundColor = NSColor.lightGray.cgColor
            shadowView.layer?.shadowColor = NSColor.black.cgColor
            shadowView.layer?.shadowOffset = NSSize(width:0, height: -3)
            shadowView.layer?.shadowRadius = 6.0
            shadowView.layer?.shadowOpacity = 1.0
            
//            self.window?.addSubview(tableView)
            //self.window?.addSubview(shadowView)
            
            if tableContainer.superview == nil {
                superview?.addSubview(tableContainer, positioned: .above, relativeTo: nil)
            }
            
            if shadowView.superview == nil {
                superview?.wantsLayer = true
                superview?.addSubview(shadowView, positioned: .below, relativeTo: tableContainer)
            }
            
//            superview?.addSubview(shadowView, positioned: .below, relativeTo: tableView)
            
        } else {
            tableContainer = NSScrollView(frame: CGRect(x:0, y:0, width:self.frame.width, height:0))
            tableView = SearchTextFieldTableView(frame: CGRect.zero)
            
            let col1 = NSTableColumn(identifier: "col1")
            col1.width = self.frame.width
            
            tableView?.addTableColumn(col1)
            tableContainer?.documentView = tableView
            tableContainer?.autohidesScrollers = true
            tableContainer?.hasVerticalScroller = true
            tableContainer?.isHidden = true
            
            // TODO shadowView should be part of tableContainer view hierarchy
            shadowView = NSView(frame: CGRect.zero)
            shadowView?.isHidden = true
        }
        
        redrawSearchTableView()
    }
    
    // Re-set frames and theme colors
    fileprivate func redrawSearchTableView() {
        if let tableContainer = tableContainer, let tableView = tableView {
            let positionGap: CGFloat = 0
            
            // TODO how to do with iOS keyboard down and up direction??
            var tableHeight = min((tableView.rowHeight + tableView.intercellSpacing.height) * CGFloat(tableView.numberOfRows) + positionGap,
                                  tableContainer.documentView?.frame.size.height ?? 0.0)
            
            if maxResultsListHeight > 0 {
                tableHeight = min(tableHeight, CGFloat(self.maxResultsListHeight))
            }
            
            let textFieldBezelGap: CGFloat = 4
            let textField2TableViewSpacing: CGFloat = 3
            var tableViewFrame = CGRect(x: 0, y: tableHeight, width: frame.size.width - textFieldBezelGap, height: tableHeight)
            tableViewFrame.origin = self.convert(tableViewFrame.origin, to: self.superview)
            tableViewFrame.origin.x += textFieldBezelGap / 2.0
            tableViewFrame.origin.y -= frame.size.height + textField2TableViewSpacing
            tableContainer.frame = tableViewFrame
            
            var shadowFrame = CGRect(x: 0, y: 0, width: frame.size.width - 6, height: 1)
            shadowFrame.origin = self.convert(shadowFrame.origin, to: self.superview)
            shadowFrame.origin.x += 3
            shadowFrame.origin.y = tableContainer.frame.origin.y
            shadowView!.frame = shadowFrame
            
//            tableView.borderColor = theme.borderColor.cgColor
//            tableView.separatorColor = theme.separatorColor
            tableView.backgroundColor = theme.bgColor
            
            tableView.reloadData()
        }
    }
    
    open func typingDidStop() {
        if userStoppedTypingHandler != nil {
            self.userStoppedTypingHandler!()
        }
    }
    
    open override func becomeFirstResponder() -> Bool {
        if self.startVisible {
            // some slight delay may be beneficial so that it may appear focus and tableView show-up in the same time.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.makeTableVisible()
            }
            filter(true)
        }
        return super.becomeFirstResponder()

    }
    
    open func makeTableVisible() {
        self.needsLayout = true
        tableContainer?.isHidden = false
        shadowView?.isHidden = false
    }
    
    open func showTable() {
        self.makeTableVisible()
        filter(true)
    }
    
    // Handle text field changes
    override open func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
//        Swift.print("textFieldDidChange")
        self.makeTableVisible()
        
        // Detect pauses while typing
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.8, target: self, selector: #selector(SearchTextField.typingDidStop), userInfo: self, repeats: false)
        
        if stringValue.isEmpty {
            clearResults()
            tableView?.reloadData()
        } else {
            filter(false)
        }
    }
    
    override open func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
//        Swift.print("textFieldDidBeginEditing")
        self.makeTableVisible()
        
        if startVisible && stringValue.isEmpty {
            clearResults()
            filter(true)
        }
    }
    
    override open func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
//        Swift.print("textFieldDidEndEditing")
        self.makeTableVisible()
        
        clearResults()
        tableView?.reloadData()
    }
    
    // TODO SearchTextField.textFieldDidEndEditingOnExit??
    open func textFieldDidEndEditingOnExit() {
        if let title = filteredResults.first?.title {
            self.stringValue = title
        }
    }

    fileprivate func filter(_ addAll: Bool) {
        clearResults()
        
        // locate prefix matches in data set
        if !addAll {
            for i in 0 ..< filterDataSource.count {
                var item = filterDataSource[i]
                if item.title.lowercased().hasPrefix(searchableStringValue.lowercased()) {
                    item.searchAttributes = (highlightAttributes, range: NSMakeRange(0, searchableStringValue.length()))
                    filteredResults.append(item)
                }
            }
        }
        
        // locate partial matches in data set
        for i in 0 ..< filterDataSource.count {
            var item = filterDataSource[i]
            
            if !filteredResults.contains(where:{$0.title == item.title}) {
                let titleFilterRange = (item.title as NSString).range(of: searchableStringValue, options: .caseInsensitive)
                if addAll || titleFilterRange.location != NSNotFound {
                    item.searchAttributes = (highlightAttributes, range: titleFilterRange)
                    filteredResults.append(item)
                }
            }
        }
    
        if filteredResults.count > 0 && shouldApplyFilteredText() {
            if let first = filteredResults.first {
                if first.title.hasPrefix(searchableStringValue) {
                    // fill-up the text field with the result of first hit.
                    let start = searchableStringValue.length()
                    if searchableStringValue != "" {
                        if let firstResult = filteredResults.first {
                            self.stringValue = firstResult.title
                            self.fieldEditor?.selectedRange = NSMakeRange(start, self.stringValue.length())
                        }
                    }
                }
            }
        }
        
        let searchableString = searchableStringValue
        tableView?.reloadData{
            // revalidate first hit in case of race condition.
            if let first = self.filteredResults.first {
                if first.title.hasPrefix(searchableString) {
                    self.allowClearField = false
                    self.tableView?.selectRowIndexes([0], byExtendingSelection: false)
                } else {
                    self.tableView?.deselectAll(self)
                }
            }
        }
    }
    
    func shouldApplyFilteredText() -> Bool {
        var result: Bool = false
        if searchableStringValue.length() > prevLength {
            result = true
        }
        prevLength = searchableStringValue.length()
        return result
    }
    
    // Clean filtered results
    fileprivate func clearResults() {
        filteredResults.removeAll()
    }
}

extension SearchTextField: NSTextFieldDelegate {
    
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool{
        guard let tableView = tableView else {
            return false
        }
        
//        Swift.print(commandSelector)
        
        // handle up/down arrow keys
        if commandSelector == #selector(moveUp) || commandSelector == #selector(moveDown){
            var selectRow = tableView.selectedRow
            if commandSelector == #selector(moveUp) {
                selectRow -= 1
            }
            
            if commandSelector == #selector(moveDown) {
                selectRow += 1
            }
            
            if 0..<filteredResults.count ~= selectRow {
                tableView.scrollRowToVisible(selectRow)
                
                // async - otherwise selection may loss.
                DispatchQueue.main.async {
                    tableView.selectRowIndexes([selectRow], byExtendingSelection: false)
                }
            }
            
            return true
        }
        
        return false
    }
}

extension SearchTextField: NSTableViewDelegate, NSTableViewDataSource {
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        guard let tableContainer = tableContainer, let shadowView = shadowView else {
            Swift.print("guard error")
            return 0
        }
        if !tableContainer.isHidden {
            tableContainer.isHidden = (filteredResults.count == 0)
            shadowView.isHidden = (filteredResults.count == 0)
        }
        
        if maxNumberOfResults > 0 {
            return min(filteredResults.count, maxNumberOfResults)
        } else {
            return filteredResults.count
        }
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cell = tableView.make(withIdentifier: SearchTextField.cellIdentifier, owner: nil) as! NSTextField?
        if cell == nil {
            cell = NSTextField(frame:CGRect.zero)
            cell?.font = self.font
            cell?.identifier = SearchTextField.cellIdentifier
            cell?.drawsBackground = false
//            cell?.backgroundColor = NSColor.red
            
            cell?.isBezeled = false
            cell?.isEditable = false
        }
        
        cell?.attributedStringValue = filteredResults[row].attributedTitle
        
//        cell?.layer?.backgroundColor = NSColor.clear.cgColor
//        cell.layoutMargins = EdgeInsets.zero
//        cell.preservesSuperviewLayoutMargins = false
        
//        cell?.textField?.font = theme.font
//        cell?.textField?.textColor = theme.fontColor
//        
//        cell?.textField?.stringValue = filteredResults[row].title
//        cell?.imageView?.image = filteredResults[row].image
//        
//        cell?.objectValue = filteredResults[row]
        
        // TODO attributed text and detail text
        
//        cell.selectionStyle = .none
        return cell
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableView = self.tableView {
            
            // tableView.selectedRow maybe -1 on deselection
            if 0..<filteredResults.count ~= tableView.selectedRow {
                if allowClearField {
                    self.stringValue = filteredResults[tableView.selectedRow].title
                    self.fieldEditor?.selectedRange = NSMakeRange(self.stringValue.length(), self.stringValue.length())
                }
                allowClearField = true
                
                if itemSelectionHandler != nil {
                    itemSelectionHandler!(filteredResults[tableView.selectedRow])
                }
                
            }
            
            // update previous length for suggestion tracking.
            prevLength = searchableStringValue.length()
            
            //TODO mouse click to dismiss listings
//            clearResults()
//            tableView.reloadData()
        }
    }
    
}

////////////////////////////////////////////////////////////////////////
// Search Text Field Theme

public struct SearchTextFieldTheme {
    public var cellHeight: CGFloat
    public var bgColor: NSColor
    public var borderColor: NSColor
    public var separatorColor: NSColor
    public var font: NSFont
    public var fontColor: NSColor
    
    init(cellHeight: CGFloat, bgColor:NSColor, borderColor: NSColor, separatorColor: NSColor, font: NSFont, fontColor: NSColor) {
        self.cellHeight = cellHeight
        self.borderColor = borderColor
        self.separatorColor = separatorColor
        self.bgColor = bgColor
        self.font = font
        self.fontColor = fontColor
    }
    
    public static func lightTheme() -> SearchTextFieldTheme {
        return SearchTextFieldTheme(cellHeight: 30, bgColor: NSColor (red: 1, green: 1, blue: 1, alpha: 0.6), borderColor: NSColor (red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0), separatorColor: NSColor.clear, font: NSFont.systemFont(ofSize: 10), fontColor: NSColor.black)
    }
    
    public static func darkTheme() -> SearchTextFieldTheme {
        return SearchTextFieldTheme(cellHeight: 30, bgColor: NSColor (red: 0.8, green: 0.8, blue: 0.8, alpha: 0.6), borderColor: NSColor (red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0), separatorColor: NSColor.clear, font: NSFont.systemFont(ofSize: 10), fontColor: NSColor.white)
    }
}

////////////////////////////////////////////////////////////////////////
// Filter Item

public struct SearchTextFieldItem {
    // Private vars
    private var backingAttributedTitle: NSAttributedString
    
    // Public interface
    public var title: String {
        get {
            return backingAttributedTitle.string
        }
    }
    
    public var searchAttributes: (attributes: [String: Any], NSRange)?
    
    public var attributedTitle: NSAttributedString {
        get {
            if let searchAttributes = self.searchAttributes {
                let result: NSMutableAttributedString = NSMutableAttributedString(attributedString: backingAttributedTitle)
                result.addAttributes(searchAttributes.0, range: searchAttributes.1)
                return result
            }
            return backingAttributedTitle
        }
    }
    
    public init(title: String) {
        self.backingAttributedTitle = NSAttributedString(string: title)
        self.searchAttributes = nil
    }
    
    public init(attributedString: NSAttributedString) {
        self.backingAttributedTitle = attributedString
        self.searchAttributes = nil
    }

}

public typealias SearchTextFieldItemHandler = (_ item: SearchTextFieldItem) -> Void

class SearchTextFieldTableView: NSTableView {
    // to enable NSTableView click-through
    // http://lists.apple.com/archives/cocoa-dev/2008/Sep/msg00130.html
    override open var needsPanelToBecomeKey: Bool {
        get {
            return false
        }
    }
    
    var reloadDataCompletionBlock: (() -> Void)?
    
    override func layout() {
        super.layout()
        
        
        if reloadDataCompletionBlock != nil {
            reloadDataCompletionBlock!()
        }
    }
    
    func reloadData(completion:@escaping () -> Void) {
        reloadDataCompletionBlock = completion
        super.reloadData()
    }
}

extension String {
    func length() -> Int {
        return lengthOfBytes(using: String.Encoding.utf8)
    }
    
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }
    
    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return substring(from: fromIndex)
    }
    
    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return substring(to: toIndex)
    }
    
    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return substring(with: startIndex..<endIndex)
    }
}
