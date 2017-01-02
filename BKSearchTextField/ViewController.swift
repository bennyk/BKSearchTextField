//
//  ViewController.swift
//  BKSearchTextField
//
//  Created by Benny Khoo on 02/01/2017.
//  Copyright © 2017 Benny Khoo. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var pereField: SearchTextField!
    @IBOutlet weak var acronymTextField: SearchTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // 1 - Configure a simple search text view
        configureSimpleSearchTextField()
        
        // 2 - Configure a custom search text view
        configureCustomSearchTextField()
    }
    
    // 1 - Configure a simple search text view
    func configureSimpleSearchTextField() {
        // Start visible - Default: false
        pereField.startVisible = true
        pereField.maxNumberOfResults = 6
        
        // Set data source
        pereField.filterStrings(pereChars)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    // 2 - Configure a custom search text view
    func configureCustomSearchTextField() {
        // Set theme - Default: light
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
    }
    
     func filterAcronymInBackground(_ criteria: String, callback: @escaping ((_ results: [SearchTextFieldItem]) -> Void)) {
        let url = URL(string: "http://www.nactem.ac.uk/software/acromine/dictionary.py?sf=\(criteria)")
        
        if let url = url {
            print("sending query", url)
            let task = URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
                do {
                    if let data = data {
                        let jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [[String:AnyObject]]
                        
                        if let firstElement = jsonData.first {
                            let jsonResults = firstElement["lfs"] as! [[String: AnyObject]]
                            
                            var results = [SearchTextFieldItem]()
                            
                            for result in jsonResults {
                                results.append(SearchTextFieldItem(title: result["lf"] as! String))
                            }
                            
                            DispatchQueue.main.async {
                                callback(results)
                            }
                        } else {
                            DispatchQueue.main.async {
                                callback([])
                            }
                        }
                    }
                }
                catch {
                    print("Network error: \(error)")
                    DispatchQueue.main.async {
                        callback([])
                    }
                }
            })
            
            task.resume()
        }
    }
    
    let pereChars = ["Jacob Portman",
                     "Emma Bloom",
                     "Hugh Apiston",
                     "Enoch O'Connor",
                     "Olive Abroholos Elephanta",
                     "Millard Nullings",
                     "Fiona Frauenfeld",
                     "Bronwyn Bruntley",
                     "Victor Bruntley",
                     "Horace Somnusson",
                     "Claire Densmore",
                     "The Twins",
                     "Abraham Portman",
                     "Miss Alma LeFay Peregrine",
                     "Miss Esmerelda Avocet",
                     "Miss Balenciaga Wren",
                     "Miss Nightjar",
                     "Olivia",
                     "Miss Finch",
                     "The Elder Miss Finch (Aunt of the younger Miss Finch)",
                     "Miss Bunting",
                     "Miss Treecreeper",
                     "Miss Crow",
                     "Miss Jackdaw",
                     "Miss Raven",
                     "Miss Kestrel",
                     "Miss Gannett",
                     "Miss Thrush",
                     "Miss Hornbill",
                     "Miss Glassbill",
                     "Miss Waxwing",
                     "Miss Troupial",
                     "Miss Grebe",
                     "Miss Loon",
                     "Miss Bobolink",
                     "Miss Farefield",
                     "Miss Goshawk",
                     "Jack 'Caul' Bentham",
                     "Myron Bentham",
                     "The Bone Brothers",
                     "Melina Manon",
                     "Marcie",
                     "Althea Grimmebwald",
                     "Sam",
                     "Radi",
                     "Sergei Andropov",
                     "The Peculiar Clown",
                     "Snake-Charmer girl",
                     "Plain looking boy",
                     "Benteret",
                     "Charlotte",
                     "Sharon",
                     "Mother Dust",
                     "Reynaldo",
                     "Sammy",
                     "Nim",
                     "Perplexus Anomalous",
                     "Kim",
                     "Don Fernando",
                     "Carlotta",
                     "Carlita",
                     "Ambro dealer",
                     "Sophronia Winstead",
                     "G. Fünke",
                     "J. Edwin Bragg",
                     "Lorraine",
                     "Carlos",
                     "Grunt",
                     "Addison MacHenry",
                     "Deirdre",
                     "Armageddon Chickens",
                     "Miss Wren's Peculiar Pigeons",
                     "Winnifred",
                     "Pompey",
                     "Ca'ab Magda",
                     "PT",
                     "Alexi",
                     "Unnamed Grimbear cubs"]


}

