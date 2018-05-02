//
//  SessionManager.swift
//  Dron
//
//  Created by Bruno Guidolim on 14.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import RxSwift

// MARK: - Definitions

public enum HTTPMethod: String {
    case get = "GET"
}

enum SessionManagerError: Error {
    case invalidURL
}

public typealias Parameters = Any

private struct TaskCompletion {
    let taskId: Int?
    let observer: AnyObserver<Data>
    let useCache: Bool
    var responseData: Data
}

extension TaskCompletion: Equatable {
    static func == (lhs: TaskCompletion, rhs: TaskCompletion) -> Bool {
        return lhs.taskId == rhs.taskId
    }
}

// MARK: - Session Manager

public final class SessionManager: NSObject {
    private var session: URLSession?
    private let queue = DispatchQueue(label: "com.guidolim.Dron.SessionManager.queue")
    fileprivate var taskCompletions = [TaskCompletion]()

    override init() {
        super.init()

        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration,
                             delegate: self,
                             delegateQueue: nil)
    }

    func request(url: URL?,
                 method: HTTPMethod,
                 params: Parameters?,
                 useCache: Bool) -> Observable<Data> {

        guard let url = url else {
            return Observable.error(SessionManagerError.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        return Observable.create { observer -> Disposable in
            let task = self.session?.dataTask(with: request)
            let taskCompletion = TaskCompletion(taskId: task?.taskIdentifier,
                                                observer: observer,
                                                useCache: useCache,
                                                responseData: Data())
            self.queue.sync {
                self.taskCompletions.append(taskCompletion)
            }
            task?.resume()

            return Disposables.create {
                task?.cancel()
            }
        }
    }

    func invalidateSession() {
        session?.invalidateAndCancel()
    }

    private func removeTaskFromQueue(_ taskCompletion: TaskCompletion) {
        queue.sync {
            if let index = taskCompletions.index(of: taskCompletion) {
                taskCompletions.remove(at: index)
            }
        }
    }

    private func taskCompletion(by taskId: Int) -> TaskCompletion? {
        var taskCompletion: TaskCompletion?
        queue.sync {
            taskCompletion = self.taskCompletions.first(where: { $0.taskId == taskId })
        }
        return taskCompletion
    }
}

// MARK: - URLSession Delegate

extension SessionManager: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.sync {
            if let index = taskCompletions.index(where: { $0.taskId == dataTask.taskIdentifier }) {
                taskCompletions[index].responseData.append(data)
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskCompletion = taskCompletion(by: task.taskIdentifier) else {
            return
        }
        guard let error = error as NSError? else {
            do {
                try JSONSerialization.jsonObject(with: taskCompletion.responseData,
                                                 options: .mutableContainers)
                taskCompletion.observer.on(.next(taskCompletion.responseData))
                taskCompletion.observer.on(.completed)
            } catch {
                taskCompletion.observer.on(.error(error))
            }
            removeTaskFromQueue(taskCompletion)
            return
        }

        if error.code != NSURLErrorCancelled,
            taskCompletion.useCache,
            let request = task.currentRequest,
            let cachedResponse = URLCache.shared.cachedResponse(for: request),
            let task = task as? URLSessionDataTask {
            urlSession(session, dataTask: task, didReceive: cachedResponse.data)
            urlSession(session, task: task, didCompleteWithError: nil)
            return
        }

        taskCompletion.observer.on(.error(error))
        removeTaskFromQueue(taskCompletion)
    }
}
