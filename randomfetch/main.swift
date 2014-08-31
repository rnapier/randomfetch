//
//  main.swift
//  randomfetch
//
//  Created by Rob Napier on 8/30/14.
//  Copyright (c) 2014 Rob Napier. All rights reserved.
//


import Foundation

class Page {
  let title: String
  let identifier: Int
  init(title: String, identifier: Int) {
    self.title = title
    self.identifier = identifier
 }
}

extension Page : Printable {
  var description: String { return self.title }
}

func apiResult<T>(url: NSURL, parser: NSData -> Result<T> ) -> Future<Result<T>> {
  return Future(exec: gcdExecutionContext) {
    var error: NSError?
    let data = NSURLConnection.sendSynchronousRequest(NSURLRequest(URL: url), returningResponse: nil, error: &error)
    switch (data, error) {

    case (_, .Some(let error)):
      return .Failure(error)

  case (.Some(let data), _):
    return parser(data)

  default:
    fatalError("Did not receive an error or data.")
  }
}
}

func randomPage() -> Future<Result<Page>> {
  return apiResult(NSURL(string: "http://en.wikipedia.org/w/api.php?action=query&format=json&list=random&rnlimit=1")) { $0
      |> asJSON           >>== asJSONDictionary
    >>== forKey("query")  >>== asJSONDictionary
    >>== forKey("random") >>== asJSONArray
    >>== atIndex(0)       >>== asJSONDictionary
    >>== asPage
}
}

func imagePageTitlesForPage(page: Page) -> Future<Result<[String]>> {
  // Example JSON: https://en.wikipedia.org/w/api.php?action=query&titles=Albert%20Einstein&prop=images&format=jsonfm
  let title = (page.title as NSString).stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!

  let url = NSURL(string: "http://en.wikipedia.org/w/api.php?action=query&titles=\(title)&prop=images&format=json")
  return apiResult(url) { $0
      |> asJSON          >>== asJSONDictionary
    >>== forKey("query") >>== asJSONDictionary
    >>== forKey("pages") >>== asJSONDictionary
    >>== forKey(toString(page.identifier)) >>== asJSONDictionary
    >>== forKey("images") >>== asJSONArray |> rescueWith([])

    >>== forEach { $0 |> asJSONDictionary
                   >>== forKey("title") >>== asString
                 }
  }
}

func imagePageTitlesForPossiblePage(page: Result<Page>) -> Future<Result<[String]>> {
  switch page {
    case .Success(let pageBox): return imagePageTitlesForPage(pageBox.unbox)
    case .Failure(let error): return Future(exec: gcdExecutionContext) { .Failure(error) }
  }
}


// pageTitles is a Future<Result<[String]>
let pageTitles = imagePageTitlesForPage(Page(title: "Albert Einstein", identifier: 736))

// output maps teh array down to a Future<Result<String>>
let output = pageTitles.map { result in result.map { titles in join("\n", titles) } }

// At this point, everything is still running asynchronously.

// This call to result() will block until the processing is completed
// result is a Result<String>
let result = output.result()

println(result)
