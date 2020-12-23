//
//  GCDKit.swift
//  Tools
//
//  Created by 杨名宇 on 2020/12/23.
//

import Foundation

class GCDKit {
    private let globalQueue = DispatchQueue.global()
    private let mainQueue = DispatchQueue.main
    
    private var handleBlockArr: [() -> ()] = []
    private var group = DispatchGroup()
    
        
    // 执行耗时操作，回调主线程
    // 需要返回结果
    func handle<T>(somethingLong: @escaping () -> T, finished: @escaping (T) -> ()) {
        globalQueue.async {
            let data = somethingLong()
            self.mainQueue.async {
                finished(data)
            }
        }
    }
    // 不需要返回结果
    func handle(somethingLong: @escaping () -> (), finished: @escaping () -> ()) {
        let workItem = DispatchWorkItem {
            somethingLong()
        }
        globalQueue.async(execute: workItem)
        workItem.wait()
        finished()
    }
    // 串行耗时
    // 向全局并发队列添加同步任务
    func wait(code: @escaping () -> ()) -> GCDKit {
        handleBlockArr.append(code)
        return self
    }
    // 处理完成，主线程回调
    func finished(code: @escaping () -> ()) {
        globalQueue.async {
            for workItem in self.handleBlockArr {
                workItem()
            }
            self.handleBlockArr.removeAll()
            self.mainQueue.async {
                code()
            }
        }
    }
    // 并发耗时
    func handle(code: @escaping () -> ()) -> GCDKit {
        let queue = DispatchQueue(label: "", attributes: .concurrent)
        let workItem = DispatchWorkItem {
            code()
        }
        queue.async(group: group, execute: workItem)
        return self
    }
    func barrierHandle(code: @escaping () -> ()) -> GCDKit {
        let queue = DispatchQueue(label: "", attributes: .concurrent)
        let workItem = DispatchWorkItem(flags: .barrier) {
            code()
        }
        queue.async(group: group, execute: workItem)
        return self
    }
    func allDone(code: @escaping () -> ()) {
        group.notify(queue: .main, execute: {
            code()
        })
    }
    // 延时
    func run(when: DispatchTime, code: @escaping () -> ()) {
        mainQueue.asyncAfter(deadline: when) {
            code()
        }
    }
    // 并发遍历
    func map<T>(data: [T], code: (T) -> ()) {
        DispatchQueue.concurrentPerform(iterations: data.count) { (i) in
            code(data[i])
        }
    }
    // timer
    class Timer {
        private let internalTimer: DispatchSourceTimer
        private var isRunning = false
        public let repeats: Bool
        public typealias TimerHandler = (Timer) -> Void
        private var handler: TimerHandler
        
        public init(interval: DispatchTimeInterval,
                    repeats: Bool = false,
                    leeway: DispatchTimeInterval = .seconds(0),
                    queue: DispatchQueue = .main,
                    handler: @escaping TimerHandler) {
            self.handler = handler
            self.repeats = repeats
            internalTimer = DispatchSource.makeTimerSource(queue: queue)
            internalTimer.setEventHandler { [weak self] in
                guard let self = self else { return }
                handler(self)
            }
            if repeats {
                internalTimer.schedule(deadline: .now() + interval, repeating: interval, leeway: leeway)
            }
            else {
                internalTimer.schedule(deadline: .now() + interval, leeway: leeway)
            }
        }
        
        func fire() {
            handler(self)
            if !repeats {
                internalTimer.cancel()
            }
        }
        
        func start() {
            if !isRunning {
                internalTimer.resume()
                isRunning = true
            }
        }
        
        func suspend() {
            if isRunning {
                internalTimer.suspend()
                isRunning = false
            }
        }
        
        func cancel() {
            internalTimer.cancel()
            isRunning = false
        }
        
        deinit {
            internalTimer.cancel()
        }
    }
    
    // 最大并发数
    func testMaxConcurrentCount(_ count: Int) {
        let semaphore = DispatchSemaphore(value: count)
        let queue = DispatchQueue(label: "", attributes: .concurrent)
        func doSomething(label: String, cost: UInt32, complete: @escaping () -> ()) {
            print("start task: \(label)")
            sleep(cost)
            print("end task: \(label)")
            complete()
        }

        queue.async {
            semaphore.wait()
            doSomething(label: "1", cost: 2) {
                print(Thread.current)
                semaphore.signal()
            }
        }
        queue.async {
            semaphore.wait()
            doSomething(label: "2", cost: 2) {
                print(Thread.current)
                semaphore.signal()
            }
        }
        queue.async {
            semaphore.wait()
            doSomething(label: "3", cost: 2) {
                print(Thread.current)
                semaphore.signal()
            }
        }
        queue.async {
            semaphore.wait()
            doSomething(label: "4", cost: 2) {
                print(Thread.current)
                semaphore.signal()
            }
        }
        queue.async {
            semaphore.wait()
            doSomething(label: "5", cost: 2) {
                print(Thread.current)
                semaphore.signal()
            }
        }
    }


    // GCDGroup

    func testGroup() {
        func networkTask(label:String, cost:UInt32, complete:@escaping ()->()){
            print("Start network Task task\(label)")
            DispatchQueue.global().async {
                sleep(cost)
                print("End networkTask task\(label)")
                DispatchQueue.main.async {
                    complete()
                }
            }
        }

        let group = DispatchGroup()
        group.enter()
        networkTask(label: "1", cost: 2, complete: {
            group.leave()
        })

        group.enter()
        networkTask(label: "2", cost: 4, complete: {
            group.leave()
        })

        group.enter()
        networkTask(label: "3", cost: 2, complete: {
            group.leave()
        })

        group.enter()
        networkTask(label: "4", cost: 4, complete: {
            group.leave()
        })

        group.notify(queue: .main, execute:{
            print("All network is done")
        })

    }

    // 读写锁
    class XXXManager {
        private let concurrentQueue = DispatchQueue(label: "concurrentQueue", attributes: .concurrent)
        private var dictionary: [String: Any] = [:]

        public func set(_ value: Any?, forKey key: String) {
            concurrentQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.dictionary[key] = value
            }
        }

        public func object(forKey key: String) -> Any? {
            var result: Any?
            concurrentQueue.async { [weak self] in
                guard let self = self else { return }
                result = self.dictionary[key]
            }
            return result
        }
    }


    // 取消任务
    func testCancelWork() {
        let queue = DispatchQueue.global()
        var item: DispatchWorkItem!
        item = DispatchWorkItem {
            for i in 0 ... 10_000_000 {
                if item.isCancelled { break }
                print(i)
                sleep(1)
            }
            item = nil
        }
        queue.async(execute: item)
        queue.asyncAfter(deadline: .now() + 5) { [weak item] in
            item?.cancel()
        }
    }
}

class Test {
    var name = ""
    var num = 0
    
    func testConcurrent() {
        GCDKit().handle(somethingLong: {
            let name = "1111"
            sleep(2)
            return name
        }) { [weak self] (result: String) in
            guard let self = self else { return }
            self.name = result
            print(self.name)
        }
    }
    
    func testWaitFinish() {
        GCDKit().wait {
            self.num += 1
        }.wait {
            self.num += 2
        }.wait {
            self.num += 3
        }.finished {
            print(self.num, Thread.current)
        }
    }
    
    func testHandleDone() {
        GCDKit().handle {
            self.num += 1
        }.barrierHandle {
            self.num += 2
        }.handle {
            self.num += 3
        }.handle {
            self.num += 4
        }.barrierHandle {
            self.num += 5
        }.allDone {
            print(self.num, Thread.current)
        }
    }
    
    func testTimer() {
        let timer = GCDKit.Timer(interval: .seconds(1), repeats: true) { (timer) in
            print("timer")
        }
        timer.start()
        GCDKit().run(when: .now() + 5) {
            timer.cancel()
        }
    }
}




