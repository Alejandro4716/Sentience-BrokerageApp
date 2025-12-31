//
//  AppFlowStore.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/18/25.
//


import SwiftUI

@MainActor
final class AppFlowStore: ObservableObject {
    //if false shows opening screen
    //if ture show main screen
    @Published var showMain: Bool = false
}
