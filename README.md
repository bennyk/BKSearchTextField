# BKSearchTextField
Text field UI for OSX that attempt to emulate the popular Safari/Chrome Omni search bar.

## Overview
BKSearchTextField is a NSTextField subclass that attempt to emulate the popular Safari/Chrome Omni search bar with automatic suggestive for text entry.

## Installation
Simply copy the single file [SearchTextField.swift](https://github.com/bennyk/BKSearchTextField/blob/master/BKSearchTextField/SearchTextField.swift "SearchTextField") to your XCode project. That is all required!

## Demo
![alt text][demo]

## Usage
```swift
// locate NSTextField in IB. Make sure it has a custom class of SearchTextField
@IBOutlet weak var pereField: SearchTextField!

pereField.filterStrings(["Jacob Portman", "Emma Bloom", "Hugh Apiston", ...])
```

### Or customize it to your heart
Please find the example project included in this repo.

```swift

@IBOutlet weak var acronymTextField: SearchTextField!

acronymTextField.theme = SearchTextFieldTheme.lightTheme()
        
// Modify current theme properties
acronymTextField.theme.font = NSFont.systemFont(ofSize: 13)
acronymTextField.theme.bgColor = NSColor (red: 0.9, green: 0.9, blue: 0.9, alpha: 0.3)
acronymTextField.theme.borderColor = NSColor (red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
acronymTextField.theme.separatorColor = NSColor (red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5)
acronymTextField.theme.cellHeight = 50
        
// Max number of results - Default: No limit
acronymTextField.maxNumberOfResults = 5
        
// Max results list height - Default: No limit
acronymTextField.maxResultsListHeight = 200
        
// Customize highlight attributes - Default: Bold
acronymTextField.highlightAttributes = [NSBackgroundColorAttributeName: NSColor.yellow, NSFontAttributeName:NSFont.boldSystemFont(ofSize: 13)]
        
// Handle item selection - Default: title set to the text field
acronymTextField.itemSelectionHandler = {item in
    print("got selection", item.title)
}
        
// Update data source when the user stops typing
acronymTextField.userStoppedTypingHandler = {
    let criteria = self.acronymTextField.stringValue
    if criteria.characters.count > 1 {
    
        // Show loading indicator
        self.acronymTextField.showLoadingIndicator()
        self.filterAcronymInBackground(criteria) { results in
            // Set new items to filter
            self.acronymTextField.filterItems(results)
            
            // Show items in filter nonetheless
            self.acronymTextField.showTable()
            
            // Stop loading indicator
            self.acronymTextField.stopLoadingIndicator()
        }
    }
}
```

##Author

Benny Khoo, benny_khoo_99@yahoo.com

##Inspiration

BKSearchTextField was heavily inspired by another iOS sibling project by [Apasccon](https://github.com/apasccon/SearchTextField) however is optimized for keyboard interface and Cocoa.

## License

BKSearchTextField is available under the MIT license. See the LICENSE file for more info.


[demo]: https://raw.githubusercontent.com/bennyk/BKSearchTextField/master/etc/BKSearchTextField%20Demo.gif
