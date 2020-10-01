//
//  TCA_Navigation_PoCApp.swift
//  TCA-Navigation-PoC
//
//  Created by Maciej Kozlowski on 24/09/2020.
//

import SwiftUI

@main
struct TCA_Navigation_PoCApp: App {
    var body: some Scene {
        WindowGroup {
            // ContentView(
            //     store: .init(
            //         initialState: .init(),
            //         reducer: contentReducer,
            //         environment: ())
            // )
            ContentViewRoot()
        }
    }
}
