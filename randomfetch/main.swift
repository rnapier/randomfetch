//
//  main.swift
//  randomfetch
//
//  Created by Rob Napier on 8/30/14.
//  Copyright (c) 2014 Rob Napier. All rights reserved.
//


//func fetchRandomPages(count: Int, completionHandler) -> Result<[Page]> {
//  let randomURL = "http://en.wikipedia.org/w/api.php?action=query&format=json&list=random&rnlimit=\(count)"
//  var error: NSError?
//  let data = NSURLConnection.sendSynchronousRequest(NSURLRequest(URL: NSURL(string: randomURL)), returningResponse: nil, error: &error)
//
//  switch (data, error) {
//
//  case (_, .Some(let error)):
//    return .Failure(error)
//
//  case (.Some(let data), _):
//    return pagesFromRandomQueryData(data)
//
//  default:
//    fatalError("Did not receive an error or data.")
//  }
//}
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
  return apiResult(NSURL(string: "http://en.wikipedia.org/w/api.php?action=query&format=json&list=random&rnlimit=1")) { data in
         asJSON(data)     >>== asJSONDictionary
    >>== forKey("query")  >>== asJSONDictionary
    >>== forKey("random") >>== asJSONArray
    >>== atIndex(0)       >>== asJSONDictionary
    >>== asPage
}
}


func imagePageTitlesForPage(page: Page) -> Future<Result<[String]>> {
  let title = (page.title as NSString).stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
  println("http://en.wikipedia.org/w/api.php?action=query&titles=\(title)&prop=images&format=json")

  return apiResult(NSURL(string: "http://en.wikipedia.org/w/api.php?action=query&titles=\(title)&prop=images&format=json")) { data in
         asJSON(data)    >>== asJSONDictionary
    >>== forKey("query") >>== asJSONDictionary
    >>== forKey("pages") >>== asJSONDictionary
    >>== forKey(toString(page.identifier)) >>== asJSONDictionary
    >>== forKey("images") >>== asJSONArray |> rescueWith(JSONArray())
    >>== forEach { json in
               asJSONDictionary(json)
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

println(resultDescription(randomPage().result()))

let titles = randomPage().flatMap(imagePageTitlesForPossiblePage).result()
println(resultDescription(titles))

//println(resultDescription(page.result()))
