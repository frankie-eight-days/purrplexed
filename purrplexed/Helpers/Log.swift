//
//  Log.swift
//  Purrplexed
//
//  Lightweight logging using os.Logger.
//

import Foundation
import os

enum Log {
	static let analysis = Logger(subsystem: "com.purrplexed.app", category: "Analysis")
	static let network = Logger(subsystem: "com.purrplexed.app", category: "Network")
	static let permissions = Logger(subsystem: "com.purrplexed.app", category: "Permissions")
}
