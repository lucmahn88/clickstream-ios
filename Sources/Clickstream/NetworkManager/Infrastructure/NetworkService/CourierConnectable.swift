//
//  CourierConnectable.swift
//  Clickstream
//
//  Created by Luqman Fauzi on 22/10/25.
//  Copyright © 2025 Gojek. All rights reserved.
//

import Foundation
import CourierCore

protocol CourierConnectableInputs {
    
    /// Initializer
    /// - Parameters:
    ///   - performOnQueue: A queue instance on which the tasks are performed.
    ///   - userCredentials: Client's user credentials
    init(config: ClickstreamCourierConfig, userCredentials: ClickstreamClientIdentifiers)

    /// Publish Event Request message to Courier
    /// - Parameters:
    ///   - data: Data to be written/sent.
    ///   - topic: Courier's topic path
    func publishMessage(_ data: Data, topic: String) throws

    /// Disconnects the connection.
    func disconnect()
    
    /// Sets up a connectable
    /// - Parameters:
    ///   - request: URLRequest which the connectable must connect to.
    ///   - keepTrying: A control flag which tells the connectable to keep trying till the connection is not established.
    ///   - connectionCallback: A callback to update about the connection status.
    ///   - eventHandler: Courier's event handler delegate
    func setup(request: URLRequest,
               keepTrying: Bool,
               connectionCallback: ConnectionStatus?,
               eventHandler: ICourierEventHandler?) async
}

protocol CourierConnectableOutputs {
    
    /// Returns the connection state.
    var isConnected: Atomic<Bool> { get }
}

protocol CourierConnectable: CourierConnectableInputs, CourierConnectableOutputs { }
