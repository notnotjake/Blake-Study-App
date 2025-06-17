//
//  StudyAppApp.swift
//  StudyApp
//
//  Created by Blake Pawluk on 6/17/25.
//

import SwiftUI

@main
struct StudyAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
