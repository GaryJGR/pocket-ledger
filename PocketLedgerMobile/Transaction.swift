//
//  Transaction.swift
//  PocketLedgerMobile
//
//  Created by Gary Jiang on 2026-10-14.
//

import Foundation

enum TransactionKind: String, Codable {
    case expense
    case income
}

struct Transaction: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amountInCents: Int
    var kind: TransactionKind
    var category: String
    var date: Date
}
