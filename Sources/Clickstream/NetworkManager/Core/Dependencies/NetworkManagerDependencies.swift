//
//  NetworkManagerDependencies.swift
//  Clickstream
//
//  Created by Anirudh Vyas on 29/04/20.
//  Copyright © 2020 Gojek. All rights reserved.
//

import Foundation

final class NetworkManagerDependencies {
    
    private var request: URLRequest
    private let database: Database
    private let networkOptions: ClickstreamNetworkOptions

    init(with request: URLRequest, db: Database, networkOptions: ClickstreamNetworkOptions) {
        self.database = db
        self.request = request
        self.networkOptions = networkOptions
    }

    private let networkQueue = SerialQueue(label: Constants.QueueIdentifiers.network.rawValue, qos: .utility)
    private let daoQueue = DispatchQueue(label: Constants.QueueIdentifiers.dao.rawValue, qos: .utility, attributes: .concurrent)

    private lazy var reachability: NetworkReachability = {
        DefaultNetworkReachability(with: networkQueue)
    }()

    private lazy var deviceStatus: DefaultDeviceStatus = {
        DefaultDeviceStatus(performOnQueue: networkQueue)
    }()

    private lazy var appStateNotifier: AppStateNotifierService = {
        DefaultAppStateNotifierService(with: networkQueue)
    }()

    private lazy var socketPersistence: DefaultDatabaseDAO<EventRequest> = {
        DefaultDatabaseDAO<EventRequest>(database: database,
                                         performOnQueue: daoQueue)
    }()

    private lazy var courierPersistance: DefaultDatabaseDAO<CourierEventRequest> = {
        DefaultDatabaseDAO<CourierEventRequest>(database: database,
                                         performOnQueue: daoQueue)
    }()

    private lazy var keepAliveService: KeepAliveService = {
        DefaultKeepAliveServiceWithSafeTimer(with: networkQueue,
                                             duration: Clickstream.configurations.connectionRetryDuration,
                                             reachability: reachability)
    }()

    private lazy var websocketNetworkService: NetworkService = {
        WebsocketNetworkService<DefaultSocketHandler>(with: getNetworkConfig(),
                                                      performOnQueue: networkQueue)
    }()
    
    private lazy var courierNetworkService: NetworkService = {
        CourierNetworkService<DefaultCourierHandler>(with: getNetworkConfig(),
                                                     performOnQueue: networkQueue)
    }()

    private lazy var websocketRetryMech: WebsocketRetryMechanism = {
        WebsocketRetryMechanism(networkService: websocketNetworkService,
                                reachability: reachability,
                                deviceStatus: deviceStatus,
                                appStateNotifier: appStateNotifier,
                                performOnQueue: networkQueue,
                                persistence: socketPersistence,
                                keepAliveService: keepAliveService)
    }()

    private lazy var courierRetryMech: CourierRetryMechanism = {
        CourierRetryMechanism(networkOptions: networkOptions,
                              networkService: courierNetworkService,
                              reachability: reachability,
                              deviceStatus: deviceStatus,
                              appStateNotifier: appStateNotifier,
                              performOnQueue: networkQueue,
                              persistence: courierPersistance)
    }()

    private func getNetworkConfig() -> DefaultNetworkConfiguration {
        DefaultNetworkConfiguration(request: request, networkOptions: networkOptions)
    }

    func makeNetworkBuilder() -> WebsocketNetworkBuilder {
        WebsocketNetworkBuilder(networkConfigs: getNetworkConfig(),
                                retryMech: websocketRetryMech,
                                performOnQueue: networkQueue)
    }

    func makeCourierNetworkBuilder() -> CourierNetworkBuilder {
        CourierNetworkBuilder(networkConfigs: getNetworkConfig(),
                              retryMech: courierRetryMech,
                              performOnQueue: networkQueue)
    }

    var isSocketConnected: Bool {
        websocketNetworkService.isConnected
    }

    var isCourierConnected: Bool {
        courierNetworkService.isConnected
    }

    func provideClientIdentifiers(with identifiers: ClickstreamClientIdentifiers, topic: String) {
        guard let courierIdentifiers = identifiers as? CourierIdentifiers else {
            return
        }

        courierRetryMech.configureIdentifiers(with: courierIdentifiers, topic: topic)
    }
    
    func removeClientIdentifiers() {
        courierRetryMech.removeIdentifiers()
    }
}
