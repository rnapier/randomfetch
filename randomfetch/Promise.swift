//
//  Promise.swift
//  randomfetch
//
//  Created by Rob Napier on 8/31/14.
//  Copyright (c) 2014 Rob Napier. All rights reserved.
//

import Foundation

class Promise<A> {
  let future: Future<Result<A>>

  init(future: Future<Result<A>>) {
    self.future = future
  }

  func map<B>(f: A -> B) -> Promise<B> {
    return Promise<B>(future: self.future.map { $0.map(f) })
  }

  func flatMap<B>(f: A -> Promise<B>) -> Promise<B> {
    return Promise<B>(future: Future(exec: gcdExecutionContext) {
      return self.result().map(f).flatMap { $0.result() }
    })
  }

  func result() -> Result<A> {
    return future.result()
  }

  class func success(value: A) -> Promise<A> {
    return Promise(future: Future(exec: gcdExecutionContext) { Result.Success(Box(value)) })
  }

  class func failure(error: NSError) -> Promise<A> {
    return Promise(future: Future(exec: gcdExecutionContext) { Result.Failure(error) })
  }
}

func sequence<A>(promises: [Promise<A>]) -> Promise<[A]> {
  let future = Future(exec: gcdExecutionContext) {
    sequence(promises.map{ $0.result() })
  }
  return Promise(future: future)
}

func >>==<A,B>(a: Promise<A>, f: A -> Promise<B>) -> Promise<B> {
  return a.flatMap(f)
}

func <**><A,B>(a: Promise<A>, f: A -> B) -> Promise<B> {
  return a.map(f)
}

func forEach<T,U>(f: T -> Promise<U>)(array: [T]) -> Promise<[U]> {
  return sequence(array.map(f))
}

