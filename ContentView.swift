//
//  ContentView.swift
//  download yt
//
//  Created by user on 06.01.24.
//

import AppKit       // output location folder picker
import Foundation   // execute commands in zsh
import SwiftUI


/* TODO:
    - add Cancel download button that kills background thread (Button must not be affected by UI disabled)
    - add ProgressBar which parses output of yt-dlp to get % completion and shows it next to download button
*/


// set folder of this program (lives under Documents/YTDL and contains a folder called bin that stores ffmpeg and yt-dlp
let ytdlRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("YTDL")
let ytdlBin = ytdlRoot.appendingPathComponent("bin")


struct ContentView: View {
    // target URL
    @State private var url: String = ""
    
    // filetype of output (default mkv)
    @State private var filetype = UserDefaults.standard.string(forKey: "filetype") ?? "mkv"
    
    // output folder URL (default ~/Documents/YTDL)
    @State private var outputFolderPath: URL? = UserDefaults.standard.url(forKey: "outputFolderPath") ?? ytdlRoot
    
    // keep track of whether download is currently active or not
    @State private var isDownloading : Bool = false
    
    // download success popup shown
    @State private var isDownloadSuccessAlertPresented = false

    // at startup create folders ~/Documents/YTDL and ~/Documents/YTDL/bin if they do not exist already
    init() {
        createYTDLFolderIfNeeded()
    }
    
    var body: some View {
        VStack {
            
            // url
            HStack {
                Spacer().frame(width: 4) // icon sizes vary, improves overall alignment
                
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                
                Text("URL:\t\t\t\t")
                
                TextField("Paste your URL here", text: $url)
                
                // paste button
                Button(action: {
                    // set url to clipboard content
                    if let clipboardContent = NSPasteboard.general.string(forType: .string) {
                        url = clipboardContent
                    }
                    
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .imageScale(.medium)
                        .foregroundStyle(.tint) // Optional: Set the image color
                }
                
            }
            
            Spacer().frame(height: 24) // evenly spaced vertical space between the rows
            
            // output format
            HStack {
                Spacer().frame(width: 3)
                Image(systemName: "gearshape")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Picker("Output Format:\t\t", selection: $filetype) {
                               ForEach(["mp3", "opus", "mkv"], id: \.self) {
                                   Text($0)
                               }
                           }
                // horizontal picker style
                .pickerStyle(SegmentedPickerStyle())
                // when user selects different filetype, store it in userdefaults
                .onChange(of: filetype) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "filetype")
                }
                // when app is started, set last use filetype from userdefaults (default is mkv)
                .onAppear {
                    if let storedFileType = UserDefaults.standard.string(forKey: "filetype") {
                        filetype = storedFileType
                    }
                }
                
            }
            
            // output folder
            HStack {
                Image(systemName: "folder")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    
                Text("Output Folder:\t   ")
                Button("Choose Folder") {
                    // open folder picker (no files allowed)
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false

                    // display the folder picker panel
                    panel.begin { response in
                        if response == NSApplication.ModalResponse.OK {
                            outputFolderPath = panel.urls.first
                            // also store URL in userdefaults
                            if let outputFolderPath = outputFolderPath {
                                UserDefaults.standard.set(outputFolderPath, forKey: "outputFolderPath")
                            }
                        }
                    }
                }
                .padding()
                .onAppear {
                    // load last URL from UserDefaults at app startup
                    if let storedOutputFolderPath = UserDefaults.standard.url(forKey: "outputFolderPath") {
                        outputFolderPath = storedOutputFolderPath
                    }
                }
                
                if let outputFolderPath = outputFolderPath {
                    Text("\(outputFolderPath.path)")
                        .padding()
                }
                
            }
            .frame(maxWidth: .infinity, alignment: .leading) // fixes swiftui bug? where its not aligned left otherwise
            
            // start download button
            HStack {
                Button("Start Download") {
                    // if URL is empty dont do anything
                    if url == "" {
                        return
                    }
                    
                    //  TODO: check if folder is valid choice
                    
                    // every background task runs on background thread so that UI is not blocked
                    DispatchQueue.global(qos: .background).async {
                        
                        // disable UI
                        isDownloading = true
                        
                        // download ffmpeg, unpack it and make it executable
                        downloadBinary(url: "https://evermeet.cx/ffmpeg/ffmpeg-113169-ge1c1dc8347.zip"){
                            executeZshCommand("chmod +x ffmpeg")
                        }
                        
                        // download yt-dlp, make it executable and execute rest of commands
                        downloadBinary(url: "https://github.com/yt-dlp/yt-dlp/releases/download/2023.12.30/yt-dlp_macos"){
                            executeZshCommand("chmod +x yt-dlp")
                        }
                        
                        // update yt-dlp (every few months this will trigger and fix broken downloads)
                        executeZshCommand("./yt-dlp --update")
                        
                        // if URL field not-empty, determine download command (depends on filetype chosen) and start download
                        if url.count > 0 {
                            var downloadCommand = ""
                            
                            switch filetype {
                            case "mp3":
                                downloadCommand = "./yt-dlp -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 --ignore-errors --yes-playlist -o '\(outputFolderPath!.path)/%(channel)s - %(title)s.%(ext)s' \"\(url)\" --ffmpeg-location \(ytdlBin.path)"

                            case "opus":
                                downloadCommand = "./yt-dlp -f bestaudio --extract-audio --audio-format opus --remux-video opus --audio-quality 0 --ignore-errors --yes-playlist -o '\(outputFolderPath!.path)/%(channel)s - %(title)s.%(ext)s' \"\(url)\" --ffmpeg-location \(ytdlBin.path)"
                                
                            case "mkv":
                                downloadCommand = "./yt-dlp -f 'bestvideo[ext=mkv]+bestaudio[ext=m4a]/best[ext=mkv]/best' --ignore-errors --yes-playlist -o '\(outputFolderPath!.path)/%(channel)s - %(title)s.%(ext)s' \"\(url)\" --ffmpeg-location \(ytdlBin.path) --recode-video mkv"

                            default:
                                print("This can't possibly happen.")
                            }
                            
                            // start download
                            executeZshCommand(downloadCommand)
                            
                            // show success dialog when download completes
                            isDownloadSuccessAlertPresented.toggle()
                                
                        }
                        
                        // enable UI again
                        isDownloading = false
               
                    } // end of Background Thread
                    
                } // end of Button Download action
                .alert(isPresented: $isDownloadSuccessAlertPresented) {
                    // notify user that all downloads have been completed
                    Alert(
                        title: Text("Download Success"),
                        message: Text("All downloads completed successfully."),
                        dismissButton: .default(Text("Ok"))
                    )
                }
                
            } // end of Button Download HStack
            .frame(maxWidth: .infinity, alignment: .leading)


            // open download location button
            Button("Open Folder") { // Open Output Folder
                // open folder in Finder
                if NSWorkspace.shared.open(outputFolderPath!) {
                    print("Output folder opened successfully")
                } else {
                    print("Failed to open output folder")
                }
            }
            .padding(.top, 14) // add slightly more vertical space between the buttons
            .frame(maxWidth: .infinity, alignment: .leading)
            
            
            HStack {
                // show "Downloading, please wait..." while download is active
                if isDownloading {
                    // show animated loading icon
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.7)
                        .padding()
                    
                    Text("Downloading, please wait...")
                }
            }
            
            
        } // end of VStack
        .padding()
        .disabled(isDownloading)    // disable UI elements while download is active
        // note: no exceptions are possible, but it is cleaner than copypasting this line to each element that should be disabled..
        
        /*
        // Cancel Download Button
        if isDownloading {
            HStack {
                Button("Cancel Download") {
                    // kill background thread (seems to require lots of work to get this function...)
                }
            }
        }
        */
 
    }
    
    // unzips file at specified location (required for ffmpeg.zip)
    func unzipFile(at url: URL) {
        let task = Process()
        task.launchPath = "/usr/bin/unzip"
        task.arguments = ["-o", url.path, "-d", ytdlBin.path]    // -o makes it unzip without confirmation, -d specifies output destination
        
        task.launch()
        task.waitUntilExit()
        print("File unzipped successfully at: \(ytdlBin)ffmpeg")

    }
    
    // executeZshCommand expects a zsh command as input string and then executes that command
    func executeZshCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", command]
        task.currentDirectoryPath = ytdlBin.path
        
        print("----\nStarting to execute zsh command: \(command)\n")
        task.launch()
        task.waitUntilExit()
        print("Zsh successfully executed.\n----")
    
    }
    
    // downloads binaries (ffmpeg or yt-dlp), but only if it does not exist already
    func downloadBinary(url: String, completion: @escaping () -> Void) {
        // bool value that determines whether we are currently downloading ffmpeg or yt-dlp
        //      true: downloading ffmpeg, false: downloading yt-dlp
        let downloadingFfmpeg = url.hasPrefix("https://evermeet.cx/ffmpeg/")
        
        // signal that notifies us when download is finished
        let semaphore = DispatchSemaphore(value: 0)
        
        // set output name of file that was downloaded (will be .zip for ffmpeg, but no file ending for yt-dlp)
        let destinationURL = downloadingFfmpeg ? ytdlBin.appendingPathComponent("ffmpeg.zip") : ytdlBin.appendingPathComponent("yt-dlp")
        let binaryURL = downloadingFfmpeg ? ytdlBin.appendingPathComponent("ffmpeg") : ytdlBin.appendingPathComponent("yt-dlp")

        // check if the binaries exists already
        let fileManager = FileManager.default
        let binaryExistsAlready = fileManager.fileExists(atPath: binaryURL.path)
        if binaryExistsAlready {
            if downloadingFfmpeg {
                print("Ffmpeg exists already, skipping download..")
                return
            } else {
                print("Yt-dlp exists already, skipping download..")
                return
            }

        }
        
        // prepare download
        let urlToDownload = URL(string: url)!
        let task = URLSession.shared.downloadTask(with: urlToDownload) { localURL, _, error in
            if let localURL = localURL {
                do {
                    try FileManager.default.moveItem(at: localURL, to: destinationURL)
                    print("File downloaded successfully at: \(destinationURL)")
                    
                    // ffmpeg is only offered in zipped form, so unzip it
                    if downloadingFfmpeg {
                        unzipFile(at: destinationURL)
                    }

                    // signal that download etc is now complete
                    semaphore.signal()

                } catch {
                    print("Error moving file: \(error)")
                }
            } else if let error = error {
                print("Download failed with error: \(error)")
                // download failed but avoid deadlock but signaling completion
                semaphore.signal()
            }
        }
        // start download
        task.resume()
        
        // wait for download to finish
        semaphore.wait()
        
        // ok now continue with other code
        completion()
    }
    
    // create YTDL folder in Documents if it does not exist already
    private func createYTDLFolderIfNeeded() {
        // check if the YTDL folder exists, and create it if not
        if !FileManager.default.fileExists(atPath: ytdlRoot.path) {
            // create root folder YTDL
            do {
                try FileManager.default.createDirectory(at: ytdlRoot, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating YTDL root folder: \(error)")
                exit(0) // cancel program execution, nothing will work anyways if this fails
            }
            
            // then create bin folder inside
            do {
                try FileManager.default.createDirectory(at: ytdlBin, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating YTDL bin folder: \(error)")
                exit(0)
            }
        }
    }
    
}

/*
#Preview {
    ContentView()
}
*/
