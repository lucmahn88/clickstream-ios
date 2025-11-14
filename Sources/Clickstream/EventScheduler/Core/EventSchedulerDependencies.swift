//
//  EventSchedulerDependencies.swift
//  Clickstream
//
//  Created by Anirudh Vyas on 13/05/20.
//  Copyright © 2020 Gojek. All rights reserved.
//

import Foundation

/// A class that handles the dependencies pertaining to the EventScheduler Block.
final class EventSchedulerDependencies {
    
    private let socketNetworkBuider: any NetworkBuildable
    private let courierNetworkBuider: any NetworkBuildable
    private let networkOptions: ClickstreamNetworkOptions

    private let database: Database
    
    init(socketNetworkBuider: any NetworkBuildable,
         courierNetworkBuider: any NetworkBuildable,
         db: Database,
         networkOptions: ClickstreamNetworkOptions) {

        self.database = db
        self.socketNetworkBuider = socketNetworkBuider
        self.courierNetworkBuider = courierNetworkBuider
        self.networkOptions = networkOptions
    }
    
    /// A single instance of queue which ensures that all the tasks are performed on this queue.
    private let schedulerQueue = SerialQueue(label: Constants.QueueIdentifiers.scheduler.rawValue, qos: .utility)
    
    /**
     A single instance of queue which ensures that all the tasks related to warehouser are performed on this queue.
     
     The spitter is the most busy component amongst all the other components in the scheduler,
     it splits and saves to the cache so provided a separate queue to it.
     - reason - The warehouser was causing the scheduler to miss the timed deadline because of the event traffic.
    */
    private let warehouserQueue = SerialQueue(label: Constants.QueueIdentifiers.warehouser.rawValue, qos: .utility)
    
    private let daoQueue = DispatchQueue(label: Constants.QueueIdentifiers.dao.rawValue,
                                       qos: .utility,
                                       attributes: .concurrent)
    
    private lazy var schedulerService: SchedulerService = {
        return DefaultSchedulerService(with: Clickstream.configurations.priorities, performOnQueue: schedulerQueue)
    }()
    
    private lazy var appStateNotifier: AppStateNotifierService = {
        return DefaultAppStateNotifierService(with: schedulerQueue)
    }()
    
    private lazy var socketEventBatchCreator: DefaultEventBatchCreator = {
        DefaultEventBatchCreator(with: self.socketNetworkBuider, performOnQueue: schedulerQueue)
    }()
    
    private lazy var courierEventBatchCreator: CourierEventBatchCreator = {
        CourierEventBatchCreator(with: self.courierNetworkBuider, performOnQueue: schedulerQueue)
    }()

    private lazy var socketEventBatchProcessor: DefaultEventBatchProcessor = {
        DefaultEventBatchProcessor(
            with: socketEventBatchCreator,
            schedulerService: schedulerService,
            appStateNotifier: appStateNotifier,
            batchSizeRegulator: batchSizeRegulator,
            persistence: socketPersistence
        )
    }()
    
    private lazy var courierBatchProcessor: CourierEventBatchProcessor = {
        CourierEventBatchProcessor(
            with: courierEventBatchCreator,
            schedulerService: schedulerService,
            appStateNotifier: appStateNotifier,
            batchSizeRegulator: courierBatchSizeRegulator,
            persistence: courierPersistence
        )
    }()

    private lazy var socketPersistence: DefaultDatabaseDAO<Event> = {
        DefaultDatabaseDAO<Event>(database: database, performOnQueue: daoQueue)
    }()

    private lazy var courierPersistence: DefaultDatabaseDAO<CourierEvent> = {
        DefaultDatabaseDAO<CourierEvent>(database: database, performOnQueue: daoQueue)
    }()
    
    private lazy var batchSizeRegulator: DefaultBatchSizeRegulator = {
        DefaultBatchSizeRegulator()
    }()

    private lazy var courierBatchSizeRegulator: CourierBatchSizeRegulator = {
        CourierBatchSizeRegulator()
    }()

    /// Call this method to get the EventWarehouser instance.
    /// - Returns: EventWarehouser instance.
    func makeEventWarehouser() -> DefaultEventWarehouser {
        DefaultEventWarehouser(
            with: socketEventBatchProcessor,
            performOnQueue: warehouserQueue,
            persistence: socketPersistence,
            batchSizeRegulator: batchSizeRegulator
        )
    }
    
    func makeCourierEventWarehouser() -> CourierEventWarehouser {
        CourierEventWarehouser(
            with: courierBatchProcessor,
            performOnQueue: warehouserQueue,
            persistance: courierPersistence,
            batchSizeRegulator: courierBatchSizeRegulator,
            networkOptions: networkOptions
        )
    }
}
