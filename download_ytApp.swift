//
//  download_ytApp.swift
//  download yt
//
//  Created by user on 06.01.24.
//

import SwiftUI

@main
struct download_ytApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // limit how user can minimize/maximize the app window size
                // 480 is chosen so that "Choose folder" is never shortened to "Choose fol..." no matter which path is selected
                .frame(minWidth: 490, idealWidth: 550, maxWidth: .infinity, minHeight: 300, idealHeight: 360, maxHeight: .infinity)
                .navigationTitle("YTDL") // window title
        }
        
    }
}
