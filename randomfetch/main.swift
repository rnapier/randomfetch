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

func randomPages(#count: Int) -> Future<Result<[Page]>> {
  return apiResult(NSURL(string: "http://en.wikipedia.org/w/api.php?action=query&format=json&list=random&rnlimit=\(count)")) { $0
      |> asJSON           >>== asJSONDictionary
    >>== forKey("query")  >>== asJSONDictionary
    >>== forKey("random") >>== asJSONArray
    >>== forEach { $0 |> asJSONDictionary >>== asPage }
}
}

func apiResultP<T>(url: NSURL, parser: NSData -> Result<T> ) -> Promise<T> {
  return Promise(future: Future(exec: gcdExecutionContext) {
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
})
}


func randomPagesP(#count: Int) -> Promise<[Page]> {
  return apiResultP(NSURL(string: "http://en.wikipedia.org/w/api.php?action=query&format=json&list=random&rnlimit=\(count)")) { $0
      |> asJSON           >>== asJSONDictionary
    >>== forKey("query")  >>== asJSONDictionary
    >>== forKey("random") >>== asJSONArray
    >>== forEach { $0 |> asJSONDictionary >>== asPage }
}
}

func imagePageTitlesForPageP(page: Page) -> Promise<[(Page, String)]> {
  // Example JSON: https://en.wikipedia.org/w/api.php?action=query&titles=Albert%20Einstein&prop=images&format=jsonfm
  let title = (page.title as NSString).stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!

  let url = NSURL(string: "http://en.wikipedia.org/w/api.php?action=query&titles=\(title)&prop=images&format=json")
  return apiResultP(url) { $0
      |> asJSON          >>== asJSONDictionary
    >>== forKey("query") >>== asJSONDictionary
    >>== forKey("pages") >>== asJSONDictionary
    >>== forKey(toString(page.identifier)) >>== asJSONDictionary
    >>== forKey("images") >>== asJSONArray |> rescueWith([])

    >>== forEach { $0 |> asJSONDictionary
                   >>== forKey("title") >>== asString
                   <**> { (page, $0) }
                 }
  }
}

func imagePageTitlesForPage(page: Page) -> Future<Result<[(Page, String)]>> {
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
                   <**> { (page, $0) }
                 }
  }
}

func flatten<T>(array: [[T]]) -> [T] {
  return reduce(array, []) { $0 + $1 }
}


//let titles = randomPages(count: 10).map { result in result.flatMap { pages in sequence(pages.map { page in imagePageTitlesForPage(page).result() }).map(flatten) } }
//let titles = randomPagesP(count: 10)
//  >>== { sequence($0.map(imagePageTitlesForPageP)).map(flatten) }

let titles = randomPagesP(count: 10)
  >>== forEach(imagePageTitlesForPageP)
  <**> flatten


println(titles.result())
