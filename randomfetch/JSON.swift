//
//  JSON.swift
//  WikiStuff
//
//  Created by Rob Napier on 8/16/14.
//  Copyright (c) 2014 Rob Napier. All rights reserved.
//

import Foundation

// Inspired by http://robots.thoughtbot.com/efficient-json-in-swift-with-functional-concepts-and-generics

typealias JSON = AnyObject
typealias JSONArray = [JSON]
typealias JSONDictionary = [String: JSON]

func asJSON(data: NSData) -> Result<JSON> {
  var error: NSError?
  let json: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(0), error: &error)

  switch (json, error) {
  case (_, .Some(let error)):
    let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding)
    return .Failure(NSError(localizedDescription: "Expected JSON. Got: \(jsonString)", underlyingError: error))

  case (.Some(let json), _):
    return .Success(Box(json))

  default:
    fatalError("Received neither JSON nor an error")
    return .Failure(NSError())
  }
}

func asJSONArray(json: JSON) -> Result<JSONArray> {
  if let array = json as? JSONArray {
    return .Success(Box(array))
  } else {
    return .Failure(NSError(localizedDescription: "Expected array. Got: \(json)"))
  }
}

func asJSONDictionary(json: JSON) -> Result<JSONDictionary> {
  if let dictionary = json as? JSONDictionary {
    return .Success(Box(dictionary))
  } else {
    return .Failure(NSError(localizedDescription: "Expected dictionary. Got: \(json)"))
  }
}

func atIndex(index: Int)(array: JSONArray) -> Result<JSON> {
  if array.count < index {
    return .Failure(NSError(localizedDescription:"Could not get element at index (\(index)). Array too short: \(array.count)"))
  }
  return .Success(Box(array[index]))
}

func forKey(key: String)(dictionary: JSONDictionary) -> Result<JSON> {
  if let value: JSON = dictionary[key] {
    return .Success(Box(value))
  } else {
    return .Failure(NSError(localizedDescription: "Could not find element for key (\(key))."))
  }
}

func asString(json: JSON) -> Result<String> {
  if let string = json as? String {
    return .Success(Box(string))
  } else {
    return .Failure(NSError(localizedDescription: "Expected string. Got: \(json)"))
  }
}
func asStringList(json: JSON) -> Result<[String]> {
  if let stringList = json as? [String] {
    return .Success(Box(stringList))
  } else {
    return .Failure(NSError(localizedDescription: "Expected string list. Got: \(json)"))
  }
}

func asInt(json: JSON) -> Result<Int> {
  if let int = json as? Int {
    return .Success(Box(int))
  } else {
    return .Failure(NSError(localizedDescription: "Expected int. Got: \(json)"))
  }
}

func rescueWith<T>(rescue: T)(x: Result<T>) -> Result<T> {
  switch x {
  case .Success(_): return x
  case .Failure(_): return .Success(Box(rescue))
  }
}

//func asPages(titles: [String]) -> Result<[Page]> {
//  return .Success(Box(titles.map { Page(title: $0) }))
//}

func mkPage(title: String)(identifier: Int) -> Page {
  return Page(title: title, identifier: identifier)
}

func asPage(dictionary: JSONDictionary) -> Result<Page> {
  return mkPage <^>
      dictionary |> forKey("title") >>== asString <*>
      dictionary |> forKey("id") >>== asInt
}

func asPages(array: JSONArray) -> Result<[Page]> {
  return sequence(array.map {
    $0 |> asJSONDictionary
      >>== asPage
    })
}


infix operator <^> { associativity left } // Functor's fmap (usually <$>)
infix operator <*> { associativity left } // Applicative's apply
func <^><A, B>(f: A -> B, a: Result<A>) -> Result<B> {
  switch a {
  case .Success(let box): return .Success(Box(f(box.unbox)))
  case .Failure(let error): return .Failure(error)
  }
}

func <*><A, B>(f: Result<(A -> B)>, a: Result<A>) -> Result<B> {
  switch (a, f) {
  case (.Success(let boxA), .Success(let boxF)): return .Success(Box(boxF.unbox(boxA.unbox)))
  case (.Failure(let error), _): return .Failure(error)
  case (_, .Failure(let error)): return .Failure(error)
  default:
    fatalError("Impossible situation")
    return .Failure(NSError(localizedDescription: "Impossible"))
}
}
