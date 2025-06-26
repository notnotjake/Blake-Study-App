//
//  ContentView.swift
//  StudyApp - Enhanced Version with All Features
//

import SwiftUI
import CoreData
import AVFoundation
import UniformTypeIdentifiers
import MCEmojiPicker

// MARK: - Flash Photo Manager
class FlashPhotoManager {
    static let shared = FlashPhotoManager()
    
    private let photoDirectory: URL
    private let userDefaults = UserDefaults.standard
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        photoDirectory = documentsPath.appendingPathComponent("FlashcardPhotos")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
        
        print("📷 Photo directory: \(photoDirectory.path)")
        verifyPhotoFiles()
    }
    
    private func verifyPhotoFiles() {
        let photoKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("photo_") }
        var fixedCount = 0
        var removedCount = 0
        
        for key in photoKeys {
            if let storedPath = userDefaults.string(forKey: key) {
                if FileManager.default.fileExists(atPath: storedPath) {
                    // Check if path needs updating to current directory
                    if !storedPath.contains(photoDirectory.path) {
                        let fileName = URL(fileURLWithPath: storedPath).lastPathComponent
                        let correctPath = photoDirectory.appendingPathComponent(fileName).path
                        
                        if FileManager.default.fileExists(atPath: correctPath) {
                            userDefaults.set(correctPath, forKey: key)
                            fixedCount += 1
                        }
                    }
                } else {
                    // Try to find the file with expected naming
                    let components = key.components(separatedBy: "_")
                    if components.count >= 3 {
                        let flashcardID = components[1]
                        let side = components[2]
                        
                        // Look for files with different extensions
                        let extensions = ["jpg", "jpeg", "png", "heic", "heif"]
                        var foundFile = false
                        
                        for ext in extensions {
                            let expectedFileName = "\(flashcardID)_\(side).\(ext)"
                            let expectedPath = photoDirectory.appendingPathComponent(expectedFileName).path
                            
                            if FileManager.default.fileExists(atPath: expectedPath) {
                                userDefaults.set(expectedPath, forKey: key)
                                fixedCount += 1
                                foundFile = true
                                break
                            }
                        }
                        
                        if !foundFile {
                            userDefaults.removeObject(forKey: key)
                            removedCount += 1
                        }
                    }
                }
            }
        }
        
        if fixedCount > 0 || removedCount > 0 {
            userDefaults.synchronize()
            print("📷 Photo verification: fixed \(fixedCount), removed \(removedCount)")
        }
    }
    
    func savePhoto(from sourceURL: URL, flashcardID: String, side: String) -> Bool {
        let fileExtension = sourceURL.pathExtension.lowercased()
        let validExtensions = ["jpg", "jpeg", "png", "heic", "heif"]
        
        guard validExtensions.contains(fileExtension) else {
            print("❌ Invalid photo format: \(fileExtension)")
            return false
        }
        
        let fileName = "\(flashcardID)_\(side).\(fileExtension)"
        let destinationURL = photoDirectory.appendingPathComponent(fileName)
        
        do {
            // Remove existing photo if it exists (any extension)
            deletePhoto(flashcardID: flashcardID, side: side)
            
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            let key = "photo_\(flashcardID)_\(side)"
            userDefaults.set(destinationURL.path, forKey: key)
            userDefaults.synchronize()
            
            return FileManager.default.fileExists(atPath: destinationURL.path)
            
        } catch {
            print("❌ Error saving photo: \(error)")
            return false
        }
    }
    
    func getPhotoPath(flashcardID: String, side: String) -> String? {
        let key = "photo_\(flashcardID)_\(side)"
        
        if let storedPath = userDefaults.string(forKey: key) {
            if FileManager.default.fileExists(atPath: storedPath) {
                return storedPath
            }
        }
        
        // Try to find the file with different extensions
        let extensions = ["jpg", "jpeg", "png", "heic", "heif"]
        for ext in extensions {
            let expectedFileName = "\(flashcardID)_\(side).\(ext)"
            let expectedPath = photoDirectory.appendingPathComponent(expectedFileName).path
            
            if FileManager.default.fileExists(atPath: expectedPath) {
                userDefaults.set(expectedPath, forKey: key)
                userDefaults.synchronize()
                return expectedPath
            }
        }
        
        // Clean up broken reference
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
        return nil
    }
    
    func hasPhoto(flashcardID: String, side: String) -> Bool {
        return getPhotoPath(flashcardID: flashcardID, side: side) != nil
    }
    
    func deletePhoto(flashcardID: String, side: String) {
        let key = "photo_\(flashcardID)_\(side)"
        
        // Remove from UserDefaults
        if let path = userDefaults.string(forKey: key) {
            try? FileManager.default.removeItem(atPath: path)
        }
        userDefaults.removeObject(forKey: key)
        
        // Also try to remove files with any extension
        let extensions = ["jpg", "jpeg", "png", "heic", "heif"]
        for ext in extensions {
            let fileName = "\(flashcardID)_\(side).\(ext)"
            let filePath = photoDirectory.appendingPathComponent(fileName).path
            if FileManager.default.fileExists(atPath: filePath) {
                try? FileManager.default.removeItem(atPath: filePath)
            }
        }
        
        userDefaults.synchronize()
    }
    
    func deleteAllPhotos(flashcardID: String) {
        deletePhoto(flashcardID: flashcardID, side: "front")
        deletePhoto(flashcardID: flashcardID, side: "back")
    }
    
    func syncPhotoData() {
        userDefaults.synchronize()
        verifyPhotoFiles()
    }
}

// MARK: - Flash Audio Manager
class FlashAudioManager {
    static let shared = FlashAudioManager()
    
    private let audioDirectory: URL
    private let userDefaults = UserDefaults.standard
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioDirectory = documentsPath.appendingPathComponent("FlashcardAudio")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        
        print("📁 Audio directory: \(audioDirectory.path)")
        verifyAudioFiles()
    }
    
    private func verifyAudioFiles() {
        let audioKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("audio_") }
        var fixedCount = 0
        var removedCount = 0
        
        for key in audioKeys {
            if let storedPath = userDefaults.string(forKey: key) {
                if FileManager.default.fileExists(atPath: storedPath) {
                    if !storedPath.contains(audioDirectory.path) {
                        let fileName = URL(fileURLWithPath: storedPath).lastPathComponent
                        let correctPath = audioDirectory.appendingPathComponent(fileName).path
                        
                        if FileManager.default.fileExists(atPath: correctPath) {
                            userDefaults.set(correctPath, forKey: key)
                            fixedCount += 1
                        }
                    }
                } else {
                    let components = key.components(separatedBy: "_")
                    if components.count >= 3 {
                        let flashcardID = components[1]
                        let side = components[2]
                        let expectedFileName = "\(flashcardID)_\(side).m4a"
                        let expectedPath = audioDirectory.appendingPathComponent(expectedFileName).path
                        
                        if FileManager.default.fileExists(atPath: expectedPath) {
                            userDefaults.set(expectedPath, forKey: key)
                            fixedCount += 1
                        } else {
                            userDefaults.removeObject(forKey: key)
                            removedCount += 1
                        }
                    }
                }
            }
        }
        
        if fixedCount > 0 || removedCount > 0 {
            userDefaults.synchronize()
        }
    }
    
    func saveAudio(from sourceURL: URL, flashcardID: String, side: String) -> Bool {
        let fileName = "\(flashcardID)_\(side).m4a"
        let destinationURL = audioDirectory.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            let key = "audio_\(flashcardID)_\(side)"
            userDefaults.set(destinationURL.path, forKey: key)
            let syncSuccess = userDefaults.synchronize()
            
            let fileExists = FileManager.default.fileExists(atPath: destinationURL.path)
            let keyExists = userDefaults.string(forKey: key) != nil
            
            return fileExists && keyExists && syncSuccess
            
        } catch {
            print("❌ Error saving audio: \(error)")
            return false
        }
    }
    
    func getAudioPath(flashcardID: String, side: String) -> String? {
        let key = "audio_\(flashcardID)_\(side)"
        
        guard let storedPath = userDefaults.string(forKey: key) else {
            return nil
        }
        
        if FileManager.default.fileExists(atPath: storedPath) {
            return storedPath
        }
        
        let expectedFileName = "\(flashcardID)_\(side).m4a"
        let expectedPath = audioDirectory.appendingPathComponent(expectedFileName).path
        
        if FileManager.default.fileExists(atPath: expectedPath) {
            userDefaults.set(expectedPath, forKey: key)
            userDefaults.synchronize()
            return expectedPath
        }
        
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
        return nil
    }
    
    func hasAudio(flashcardID: String, side: String) -> Bool {
        return getAudioPath(flashcardID: flashcardID, side: side) != nil
    }
    
    func deleteAudio(flashcardID: String, side: String) {
        let key = "audio_\(flashcardID)_\(side)"
        
        if let path = userDefaults.string(forKey: key) {
            try? FileManager.default.removeItem(atPath: path)
        }
        
        let expectedFileName = "\(flashcardID)_\(side).m4a"
        let expectedPath = audioDirectory.appendingPathComponent(expectedFileName).path
        if FileManager.default.fileExists(atPath: expectedPath) {
            try? FileManager.default.removeItem(atPath: expectedPath)
        }
        
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
    }
    
    func deleteAllAudio(flashcardID: String) {
        deleteAudio(flashcardID: flashcardID, side: "front")
        deleteAudio(flashcardID: flashcardID, side: "back")
    }
    
    func listAllAudio() {
        let audioKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("audio_") }
        print("🎵 All audio files (\(audioKeys.count) total):")
        
        for key in audioKeys {
            if let path = userDefaults.string(forKey: key) {
                let exists = FileManager.default.fileExists(atPath: path)
                let fileName = URL(fileURLWithPath: path).lastPathComponent
                print("  \(key) = \(fileName) (exists: \(exists))")
            }
        }
    }
    
    func syncAudioData() {
        userDefaults.synchronize()
        verifyAudioFiles()
    }
}

// MARK: - Spaced Repetition Manager
class SpacedRepetitionManager {
    static let shared = SpacedRepetitionManager()
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    func startTimer(for flashcardID: String) {
        let key = "timer_start_\(flashcardID)"
        userDefaults.set(Date(), forKey: key)
    }
    
    func endTimer(for flashcardID: String) -> TimeInterval {
        let key = "timer_start_\(flashcardID)"
        guard let startTime = userDefaults.object(forKey: key) as? Date else { return 0 }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Store average time for this card
        let avgKey = "avg_time_\(flashcardID)"
        let timesKey = "times_count_\(flashcardID)"
        
        let currentAvg = userDefaults.double(forKey: avgKey)
        let timesCount = userDefaults.integer(forKey: timesKey)
        
        let newAvg = (currentAvg * Double(timesCount) + duration) / Double(timesCount + 1)
        
        userDefaults.set(newAvg, forKey: avgKey)
        userDefaults.set(timesCount + 1, forKey: timesKey)
        userDefaults.removeObject(forKey: key)
        
        return duration
    }
    
    func getAverageTime(for flashcardID: String) -> TimeInterval {
        let key = "avg_time_\(flashcardID)"
        return userDefaults.double(forKey: key)
    }
    
    func shouldAppearMoreFrequently(flashcardID: String) -> Bool {
        let avgTime = getAverageTime(for: flashcardID)
        return avgTime > 5.0 // Cards taking more than 5 seconds appear more frequently
    }
}

// MARK: - Audio Player Delegate Helper
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        onFinish()
    }
}

// MARK: - Content View
struct ContentView: View {
    var body: some View {
        NavigationView {
            MainMenuView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Main Menu View
struct MainMenuView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Deck.name, ascending: true)],
        animation: .default)
    private var decks: FetchedResults<Deck>
    
    @State private var showingCreateDeck = false
    @State private var refreshToggle = false
    @State private var refreshTimer: Timer?
    @State private var deckToDelete: Deck?
    @State private var showingDeleteConfirmation = false
    @State private var isEditMode = false
    @State private var selectedDecks: Set<Deck> = []
    @State private var showingStudyAll = false
    
    private var masteryPercentage: Double {
        let allCards = decks.flatMap { $0.flashcardsArray }
        guard !allCards.isEmpty else { return 0 }
        
        let masteredCards = allCards.filter { !$0.needsReview && $0.correctStreak >= 3 }
        return Double(masteredCards.count) / Double(allCards.count) * 100
    }
    
    var body: some View {
        VStack {
            if decks.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Study Decks Yet")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Tap the + button to create your first deck")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(decks, id: \.self) { deck in
                        ZStack {
                            if !isEditMode {
                                // Navigation Link (invisible)
                                NavigationLink(destination: DeckPageView(deck: deck)) {
                                    EmptyView()
                                }
                                .opacity(0)
                            }
                            
                            // Actual content
                            HStack(spacing: 16) {
                                if isEditMode {
                                    Button(action: {
                                        if selectedDecks.contains(deck) {
                                            selectedDecks.remove(deck)
                                        } else {
                                            selectedDecks.insert(deck)
                                        }
                                    }) {
                                        Image(systemName: selectedDecks.contains(deck) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedDecks.contains(deck) ? .blue : .gray)
                                            .font(.title2)
                                    }
                                }
                                
                                Text(deck.emoji ?? "📚")
                                    .font(.system(size: 40))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(deck.name ?? "Untitled Deck")
                                        .font(.headline.weight(.bold))
                                        .fontDesign(.rounded)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(deck.flashcardsArray.count) cards")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if deck.lastQuizScore > 0 {                                        Text("Last Quiz: \(Int(deck.lastQuizScore))%")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Spacer()
                                
                                if deck.isMastered {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(.systemGray5), Color(.systemGray6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                // delete action (keep this part)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.white)
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                shareDeck(deck)
                            } label: {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14, weight: .medium))
                                    )
                            }
                            .tint(.clear)
                        }
                    }
                    .onMove(perform: isEditMode ? moveDecks : nil)
                }
                .listStyle(PlainListStyle())
                
                // Mastery Progress Bar and Study All Button
                VStack(spacing: 12) {
                    HStack {
                        Text("Overall Mastery")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(masteryPercentage))%")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: masteryPercentage, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: masteryPercentage == 100 ? .green : .blue))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    
                    Button(action: {
                        showingStudyAll = true
                    }) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                            Text("Study All Decks")
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .disabled(decks.flatMap { $0.flashcardsArray }.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("Study Decks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditMode {
                    HStack {
                        Button("Cancel") {
                            isEditMode = false
                            selectedDecks.removeAll()
                        }
                        
                        if !selectedDecks.isEmpty {
                            Button("Delete (\(selectedDecks.count))") {
                                showingDeleteConfirmation = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                } else {
                    Button("Edit") {
                        isEditMode = true
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateDeck = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showingCreateDeck) {
            CreateDeckView()
        }
        .fullScreenCover(isPresented: $showingStudyAll) {
            StudyAllDecksView(decks: Array(decks))
        }
        .alert("Delete Deck(s)", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                deckToDelete = nil
                selectedDecks.removeAll()
            }
            Button("Delete", role: .destructive) {
                if isEditMode {
                    deleteSelectedDecks()
                } else if let deck = deckToDelete {
                    deleteDeck(deck)
                }
                deckToDelete = nil
                selectedDecks.removeAll()
                isEditMode = false
            }
        } message: {
            if isEditMode {
                Text("Are you sure you want to delete \(selectedDecks.count) deck(s)? This action cannot be undone and will also delete all flashcards and audio recordings in these decks.")
            } else if let deck = deckToDelete {
                Text("Are you sure you want to delete '\(deck.name ?? "this deck")'? This action cannot be undone and will also delete all flashcards and audio recordings in this deck.")
            }
        }
        .onAppear {
            FlashAudioManager.shared.syncAudioData()
            FlashPhotoManager.shared.syncPhotoData()
            FlashAudioManager.shared.listAllAudio()
            startRealTimeTimer()
        }
        .onDisappear {
            stopRealTimeTimer()
        }
        .onChange(of: refreshToggle) { _ in
            updateDeckStatuses()
        }
    }
    
    private func deleteDeck(_ deck: Deck) {
        // Delete all audio and photo files for all flashcards in this deck
        for flashcard in deck.flashcardsArray {
            if let flashcardID = flashcard.id?.uuidString {
                FlashAudioManager.shared.deleteAllAudio(flashcardID: flashcardID)
                FlashPhotoManager.shared.deleteAllPhotos(flashcardID: flashcardID)
            }
        }
        
        // Delete the deck from Core Data
        viewContext.delete(deck)
        
        do {
            try viewContext.save()
            print("✅ Deck deleted successfully")
        } catch {
            print("❌ Error deleting deck: \(error)")
        }
    }
    
    private func deleteSelectedDecks() {
        for deck in selectedDecks {
            deleteDeck(deck)
        }
    }
    
    private func moveDecks(from source: IndexSet, to destination: Int) {
        // Implement deck reordering logic here if needed
        // This would require adding an order field to the Deck entity
    }
    
    private func shareDeck(_ deck: Deck) {
        // Implement deck sharing functionality
        let deckData = exportDeckData(deck)
        let activityViewController = UIActivityViewController(activityItems: [deckData], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func exportDeckData(_ deck: Deck) -> String {
        // Create a simple text representation of the deck
        var deckText = "Deck: \(deck.name ?? "Untitled")\n\n"
        
        for flashcard in deck.flashcardsArray {
            deckText += "Front: \(flashcard.frontText1 ?? "")\n"
            if let frontText2 = flashcard.frontText2, !frontText2.isEmpty {
                deckText += "Front 2: \(frontText2)\n"
            }
            deckText += "Back: \(flashcard.backText1 ?? "")\n"
            if let backText2 = flashcard.backText2, !backText2.isEmpty {
                deckText += "Back 2: \(backText2)\n"
            }
            deckText += "\n---\n\n"
        }
        
        return deckText
    }
    
    private func startRealTimeTimer() {
        stopRealTimeTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            refreshToggle.toggle()
        }
    }
    
    private func stopRealTimeTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func updateDeckStatuses() {
        var hasChanges = false
        
        for deck in decks {
            let isDeckMastered = !deck.flashcardsArray.isEmpty && deck.flashcardsArray.allSatisfy { card in
                !card.needsReview && card.correctStreak >= 3
            }
            
            if isDeckMastered && !deck.isMastered {
                deck.isMastered = true
                hasChanges = true
            } else if !isDeckMastered && deck.isMastered {
                deck.isMastered = false
                hasChanges = true
            }
        }
        
        if hasChanges {
            do {
                try viewContext.save()
            } catch {
                print("❌ Error updating deck statuses: \(error)")
            }
        }
    }
}

// MARK: - Study All Decks View
struct StudyAllDecksView: View {
    let decks: [Deck]
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentCardIndex = 0
    @State private var isShowingBack = false
    @State private var allCards: [Flashcard] = []
    @State private var showingCompletionAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if allCards.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("All Cards Studied!")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                        Text("Great job studying across all your decks!")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack {
                        Text("\(currentCardIndex + 1) of \(allCards.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Study All Mode")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal)
                    
                    let currentCard = allCards[currentCardIndex]
                    let currentCardID = currentCard.id?.uuidString ?? "unknown"
                    
                    VStack(spacing: 16) {
                        Text(isShowingBack ? "Back" : "Front")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 12) {
                            if isShowingBack {
                                // Photo at the top
                                if FlashPhotoManager.shared.hasPhoto(flashcardID: currentCardID, side: "back"),
                                   let photoPath = FlashPhotoManager.shared.getPhotoPath(flashcardID: currentCardID, side: "back"),
                                   let image = UIImage(contentsOfFile: photoPath) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(16)
                                }
                                
                                // Text and audio
                                VStack(spacing: 8) {
                                    Text(currentCard.backText1 ?? "")
                                        .font(.title2.weight(.bold))
                                        .fontDesign(.rounded)
                                        .multilineTextAlignment(.center)
                                    if let backText2 = currentCard.backText2, !backText2.isEmpty {
                                        Text(backText2)
                                            .font(.body.weight(.medium))
                                            .fontDesign(.rounded)
                                            .multilineTextAlignment(.center)
                                    }
                                    
                                    if FlashAudioManager.shared.hasAudio(flashcardID: currentCardID, side: "back") {
                                        StudyAudioPlayer(flashcardID: currentCardID, side: "back", label: "🔊 Back Audio")
                                    }
                                }
                            } else {
                                // Photo at the top
                                if FlashPhotoManager.shared.hasPhoto(flashcardID: currentCardID, side: "front"),
                                   let photoPath = FlashPhotoManager.shared.getPhotoPath(flashcardID: currentCardID, side: "front"),
                                   let image = UIImage(contentsOfFile: photoPath) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(16)
                                }
                                
                                // Text and audio
                                VStack(spacing: 8) {
                                    Text(currentCard.frontText1 ?? "")
                                        .font(.title2.weight(.bold))
                                        .fontDesign(.rounded)
                                        .multilineTextAlignment(.center)
                                    if let frontText2 = currentCard.frontText2, !frontText2.isEmpty {
                                        Text(frontText2)
                                            .font(.body.weight(.medium))
                                            .fontDesign(.rounded)
                                            .multilineTextAlignment(.center)
                                    }
                                    
                                    if FlashAudioManager.shared.hasAudio(flashcardID: currentCardID, side: "front") {
                                        StudyAudioPlayer(flashcardID: currentCardID, side: "front", label: "🔊 Front Audio")
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(.systemGray5), Color(.systemGray6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowingBack.toggle()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width > 50 {                                    // Swipe right - mark correct
                                    withAnimation {
                                        markCorrect()
                                    }
                                } else if value.translation.width < -50 {                                    // Swipe left - mark incorrect
                                    withAnimation {
                                        markIncorrect()
                                    }
                                }
                            }
                    )
                    
                    Text("Tap card to flip • Swipe right for correct • Swipe left for incorrect")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            withAnimation {
                                markIncorrect()
                            }
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Incorrect")
                                    .fontWeight(.semibold)
                                    .fontDesign(.rounded)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        
                        Button(action: {
                            withAnimation {
                                markCorrect()
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Correct")
                                    .fontWeight(.semibold)
                                    .fontDesign(.rounded)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Study All")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupStudySession()
        }
    }
    
    private func setupStudySession() {
        allCards = decks.flatMap { $0.flashcardsArray }.shuffled()
        currentCardIndex = 0
        isShowingBack = false
    }
    
    private func markCorrect() {
        let currentCard = allCards[currentCardIndex]
        let cardID = currentCard.id?.uuidString ?? "unknown"
        
        // End timing
        SpacedRepetitionManager.shared.endTimer(for: cardID)
        
        currentCard.correctStreak += 1
        
        if currentCard.correctStreak >= 3 {
            currentCard.needsReview = false
        }
        
        nextCard()
    }
    
    private func markIncorrect() {
        let currentCard = allCards[currentCardIndex]
        let cardID = currentCard.id?.uuidString ?? "unknown"
        
        // End timing
        SpacedRepetitionManager.shared.endTimer(for: cardID)
        
        currentCard.needsReview = true
        currentCard.correctStreak = 0
        
        nextCard()
    }
    
    private func nextCard() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving card progress: \(error)")
        }
        
        if currentCardIndex < allCards.count - 1 {
            currentCardIndex += 1
            isShowingBack = false
            
            // Start timing for next card
            let nextCard = allCards[currentCardIndex]
            let nextCardID = nextCard.id?.uuidString ?? "unknown"
            SpacedRepetitionManager.shared.startTimer(for: nextCardID)
        } else {
            allCards.removeAll()
            showingCompletionAlert = true
        }
    }
}

// MARK: - Create Deck View
struct CreateDeckView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var deckName = ""
    @State private var selectedEmoji = "📚"
    @State private var navigateToDeck = false
    @State private var createdDeck: Deck?
    
    @State private var isPickerPresented = false
    
    private let commonEmojis = ["📚", "🧠", "💡", "🎓", "📖", "✏️", "🎨", "🌍", "💻", "🎵", "⚽️"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deck Name")
                            .font(.headline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        TextField("Enter deck name", text: $deckName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(15)
                    }
                    
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.headline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            Button(action: {
                                isPickerPresented.toggle()
                            }) {
                                Group {
                                    if commonEmojis.contains(selectedEmoji) {
                                        // Show plus icon when a preset emoji is selected
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.secondary)
                                    } else {
                                        // Show the custom selected emoji
                                        Text(selectedEmoji)
                                            .font(.system(size: 30))
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Circle())
                                .overlay(
                                    // Show border when custom emoji is selected
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                        .scaleEffect(1.1)
                                        .opacity(commonEmojis.contains(selectedEmoji) ? 0 : 1)
                                )
                            }
                            .emojiPicker(isPresented: $isPickerPresented, selectedEmoji: $selectedEmoji)
                            
                            ForEach(commonEmojis, id: \.self) { emoji in
                                Button(action: {
                                    selectedEmoji = emoji
                                }) {
                                    Text(emoji)
                                        .font(.system(size: 30))
                                        .frame(width: 50, height: 50)
                                        .background(selectedEmoji == emoji ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.15))
                                        .cornerRadius(8)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 2)
                                                .scaleEffect(1.1)
                                                .opacity(selectedEmoji == emoji ? 1 : 0)
                                        )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(15)
                    }
                }
                .padding()
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createDeck()
                    }
                    .disabled(deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToDeck) {
            if let deck = createdDeck {
                NavigationView {
                    DeckPageView(deck: deck)
                }
            }
        }
    }
    
    private func createDeck() {
        let newDeck = Deck(context: viewContext)
        newDeck.id = UUID()
        newDeck.name = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
        newDeck.emoji = selectedEmoji
        newDeck.createdDate = Date()
        newDeck.isMastered = false
        newDeck.lastQuizScore = 0
        
        do {
            try viewContext.save()
            createdDeck = newDeck
            presentationMode.wrappedValue.dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToDeck = true
            }
        } catch {
            print("Error creating deck: \(error)")
        }
    }
}

// MARK: - Deck Page View
struct DeckPageView: View {
    let deck: Deck
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingCreateFlashcard = false
    @State private var showingStudyMode = false
    @State private var showingReviewMode = false
    @State private var showingQuizMode = false
    @State private var refreshToggle = false
    @State private var refreshTimer: Timer?
    @State private var flashcardToDelete: Flashcard?
    @State private var showingDeleteConfirmation = false
    
    private var cardsNeedingReview: [Flashcard] {
        let manualReviewCards = deck.flashcardsArray.filter { $0.needsReview }
        let spacedRepetitionCards = deck.flashcardsArray.filter { card in
            guard let cardID = card.id?.uuidString else { return false }
            return SpacedRepetitionManager.shared.shouldAppearMoreFrequently(flashcardID: cardID)
        }
        
        let combinedCards = Array(Set(manualReviewCards + spacedRepetitionCards))
        return combinedCards
    }
    
    private var hasCardsToReview: Bool {
        !cardsNeedingReview.isEmpty
    }
    
    private var isDeckMastered: Bool {
        !deck.flashcardsArray.isEmpty && deck.flashcardsArray.allSatisfy { card in
            !card.needsReview && card.correctStreak >= 3
        }
    }
    
    var body: some View {
        VStack {
            if deck.flashcardsArray.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Flashcards Yet")
                        .font(.title3)
                        .fontDesign(.rounded)
                        .foregroundColor(.gray)
                    Text("Tap the + button to add your first flashcard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(deck.flashcardsArray, id: \.self) { flashcard in
                        ZStack {
                            // Navigation Link (invisible)
                            NavigationLink(destination: FlashcardDetailView(flashcard: flashcard)) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            // Actual content
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Front")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(flashcard.frontText1 ?? "")
                                            .font(.body.weight(.medium))
                                            .fontDesign(.rounded)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        if FlashAudioManager.shared.hasAudio(flashcardID: flashcard.id?.uuidString ?? "unknown", side: "front") {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                        }
                                        
                                        if flashcard.needsReview {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .font(.caption)
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Back")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(flashcard.backText1 ?? "")
                                            .font(.body.weight(.medium))
                                            .fontDesign(.rounded)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                    
                                    if FlashAudioManager.shared.hasAudio(flashcardID: flashcard.id?.uuidString ?? "unknown", side: "back") {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(.systemGray5), Color(.systemGray6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                // delete action (keep this part)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.white)
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                
                VStack(spacing: 12) {
                    if isDeckMastered {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Deck Mastered!")
                                    .fontWeight(.semibold)
                                    .fontDesign(.rounded)
                                    .foregroundColor(.green)
                                if deck.lastQuizScore > 0 {                                    Text("Last Quiz Results: \(Int(deck.lastQuizScore))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                showingStudyMode = true
                            }) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                    Text("Study Again")
                                        .fontWeight(.semibold)
                                        .fontDesign(.rounded)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                showingQuizMode = true
                            }) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                    Text("Quiz")
                                        .fontWeight(.semibold)
                                        .fontDesign(.rounded)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple, Color.purple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                        }
                    } else {
                        if deck.lastQuizScore > 0 {                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.blue)
                                Text("Last Quiz Results: \(Int(deck.lastQuizScore))%")
                                    .fontWeight(.medium)
                                    .fontDesign(.rounded)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        if hasCardsToReview {
                            HStack(spacing: 12) {
                                Button(action: {
                                    showingStudyMode = true
                                }) {
                                    HStack {
                                        Image(systemName: "brain.head.profile")
                                        Text("Study All")
                                            .fontWeight(.semibold)
                                            .fontDesign(.rounded)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                                
                                Button(action: {
                                    showingReviewMode = true
                                }) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                        Text("Review (\(cardsNeedingReview.count))")
                                            .fontWeight(.semibold)
                                            .fontDesign(.rounded)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Color.orange, Color.orange.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                            }
                            
                            Button(action: {
                                showingQuizMode = true
                            }) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                    Text("Take Quiz")
                                        .fontWeight(.semibold)
                                        .fontDesign(.rounded)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple, Color.purple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                        } else {
                            HStack(spacing: 12) {
                                Button(action: {
                                    showingStudyMode = true
                                }) {
                                    HStack {
                                        Image(systemName: "brain.head.profile")
                                        Text("Study Now")
                                            .fontWeight(.semibold)
                                            .fontDesign(.rounded)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                                
                                Button(action: {
                                    showingQuizMode = true
                                }) {
                                    HStack {
                                        Image(systemName: "questionmark.circle.fill")
                                        Text("Quiz")
                                            .fontWeight(.semibold)
                                            .fontDesign(.rounded)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Color.purple, Color.purple.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle(deck.name ?? "Deck")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        shareDeck()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                    }
                    
                    Button(action: {
                        showingCreateFlashcard = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateFlashcard) {
            CreateFlashcardView(deck: deck)
        }
        .fullScreenCover(isPresented: $showingStudyMode) {
            StudyModeView(deck: deck, reviewMode: false)
        }
        .fullScreenCover(isPresented: $showingReviewMode) {
            StudyModeView(deck: deck, reviewMode: true, reviewCards: cardsNeedingReview)
        }
        .fullScreenCover(isPresented: $showingQuizMode) {
            QuizModeView(deck: deck)
        }
        .alert("Delete Flashcard", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                flashcardToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let flashcard = flashcardToDelete {
                    deleteFlashcard(flashcard)
                }
                flashcardToDelete = nil
            }
        } message: {
            if let flashcard = flashcardToDelete {
                let frontText = flashcard.frontText1 ?? "this flashcard"
                Text("Are you sure you want to delete '\(frontText)'? This action cannot be undone and will also delete any audio recordings for this flashcard.")
            }
        }
        .onAppear {
            refreshView()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .onChange(of: refreshToggle) { _ in }
    }
    
    private func deleteFlashcard(_ flashcard: Flashcard) {
        // Delete audio and photo files for this flashcard
        if let flashcardID = flashcard.id?.uuidString {
            FlashAudioManager.shared.deleteAllAudio(flashcardID: flashcardID)
            FlashPhotoManager.shared.deleteAllPhotos(flashcardID: flashcardID)
        }
        
        // Delete the flashcard from Core Data
        viewContext.delete(flashcard)
        
        do {
            try viewContext.save()
            print("✅ Flashcard deleted successfully")
        } catch {
            print("❌ Error deleting flashcard: \(error)")
        }
    }
    
    private func shareDeck() {
        let deckData = exportDeckData()
        let activityViewController = UIActivityViewController(activityItems: [deckData], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func exportDeckData() -> String {
        var deckText = "Deck: \(deck.name ?? "Untitled")\n\n"
        
        for flashcard in deck.flashcardsArray {
            deckText += "Front: \(flashcard.frontText1 ?? "")\n"
            if let frontText2 = flashcard.frontText2, !frontText2.isEmpty {
                deckText += "Front 2: \(frontText2)\n"
            }
            deckText += "Back: \(flashcard.backText1 ?? "")\n"
            if let backText2 = flashcard.backText2, !backText2.isEmpty {
                deckText += "Back 2: \(backText2)\n"
            }
            deckText += "\n---\n\n"
        }
        
        return deckText
    }
    
    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            refreshToggle.toggle()
            refreshView()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func refreshView() {
        if isDeckMastered && !deck.isMastered {
            deck.isMastered = true
            try? viewContext.save()
        } else if !isDeckMastered && deck.isMastered {
            deck.isMastered = false
            try? viewContext.save()
        }
    }
}

// MARK: - Quiz Mode View
struct QuizModeView: View {
    let deck: Deck
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentCardIndex = 0
    @State private var quizCards: [Flashcard] = []
    @State private var currentAnswers: [String] = []
    @State private var selectedAnswer: Int? = nil
    @State private var correctAnswerIndex = 0
    @State private var score = 0
    @State private var showingResult = false
    @State private var showingFinalScore = false
    @State private var hasAnswered = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if showingFinalScore {
                    finalScoreView
                } else if !quizCards.isEmpty {
                    quizContentView
                    answerOptionsView
                }
            }
            .navigationTitle("Quiz Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupQuiz()
        }
    }
    
    private var finalScoreView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
            
            Text("Quiz Complete!")
                .font(.title.weight(.bold))
                .fontDesign(.rounded)
            
            Text("Final Score: \(Int(Double(score) / Double(quizCards.count) * 100))%")
                .font(.title2.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundColor(.blue)
            
            Text("\(score) out of \(quizCards.count) correct")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var quizContentView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 30)
            
            HStack {
                Text("Question \(currentCardIndex + 1) of \(quizCards.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Score: \(score)/\(quizCards.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            questionSectionView
            
            Spacer()
        }
    }
    
    private var questionSectionView: some View {
        let currentCard = quizCards[currentCardIndex]
        let currentCardID = currentCard.id?.uuidString ?? "unknown"
        
        return VStack(spacing: 16) {
            Text("Listen and Choose the Correct Answer")
                .font(.headline.weight(.bold))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
            
            if FlashPhotoManager.shared.hasPhoto(flashcardID: currentCardID, side: "front"),
               let photoPath = FlashPhotoManager.shared.getPhotoPath(flashcardID: currentCardID, side: "front"),
               let image = UIImage(contentsOfFile: photoPath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 150)
                    .cornerRadius(16)
            }
            
            VStack(spacing: 8) {
                Text(currentCard.frontText1 ?? "")
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.center)
                
                if let frontText2 = currentCard.frontText2, !frontText2.isEmpty {
                    Text(frontText2)
                        .font(.body.weight(.medium))
                        .fontDesign(.rounded)
                        .multilineTextAlignment(.center)
                }
                
                if FlashAudioManager.shared.hasAudio(flashcardID: currentCardID, side: "front") {
                    StudyAudioPlayer(flashcardID: currentCardID, side: "front", label: "🔊 Play Audio")
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(.systemGray6), Color(.systemGray4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    private var answerOptionsView: some View {
        VStack(spacing: 12) {
            ForEach(0..<currentAnswers.count, id: \.self) { index in
                Button(action: {
                    if !hasAnswered {
                        selectedAnswer = index
                        checkAnswer()
                    }
                }) {
                    HStack {
                        Text(currentAnswers[index])
                            .font(.body.weight(.medium))
                            .fontDesign(.rounded)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        
                        if hasAnswered {
                            if index == correctAnswerIndex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if index == selectedAnswer {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(
                        Group {
                            if hasAnswered {
                                if index == correctAnswerIndex {
                                    Color.green.opacity(0.2)
                                } else if index == selectedAnswer {
                                    Color.red.opacity(0.2)
                                } else {
                                    Color(.systemGray6)
                                }
                            } else {
                                Color(.systemGray6)
                            }
                        }
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                hasAnswered && index == correctAnswerIndex ? Color.green :
                                hasAnswered && index == selectedAnswer ? Color.red :
                                Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .disabled(hasAnswered)
            }
            
            if hasAnswered {
                Button(action: {
                    nextQuestion()
                }) {
                    Text(currentCardIndex < quizCards.count - 1 ? "Next Question" : "Finish Quiz")
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func setupQuiz() {
        quizCards = deck.flashcardsArray.shuffled()
        currentCardIndex = 0
        score = 0
        setupCurrentQuestion()
    }
    
    private func setupCurrentQuestion() {
        guard currentCardIndex < quizCards.count else { return }
        
        let currentCard = quizCards[currentCardIndex]
        let correctAnswer = currentCard.backText1 ?? ""
        
        // Get wrong answers from other cards
        let otherCards = deck.flashcardsArray.filter { $0 != currentCard }
        let wrongAnswers = otherCards.compactMap { $0.backText1 }.filter { !$0.isEmpty }
        
        // Create answer array with 1 correct and 3 wrong answers
        var answers = [correctAnswer]
        let shuffledWrongAnswers = wrongAnswers.shuffled()
        
        for i in 0..<min(3, shuffledWrongAnswers.count) {
            answers.append(shuffledWrongAnswers[i])
        }
        
        // Fill with generic wrong answers if needed
        while answers.count < 4 {
            answers.append("Answer \(answers.count)")
        }
        
        // Shuffle and find correct index
        answers.shuffle()
        correctAnswerIndex = answers.firstIndex(of: correctAnswer) ?? 0
        currentAnswers = answers
        
        selectedAnswer = nil
        hasAnswered = false
    }
    
    private func checkAnswer() {
        hasAnswered = true
        
        if selectedAnswer == correctAnswerIndex {
            score += 1
        }
    }
    
    private func nextQuestion() {
        if currentCardIndex < quizCards.count - 1 {
            currentCardIndex += 1
            setupCurrentQuestion()
        } else {
            finishQuiz()
        }
    }
    
    private func finishQuiz() {
        let finalScore = Double(score) / Double(quizCards.count) * 100
        deck.lastQuizScore = finalScore
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving quiz score: \(error)")
        }
        
        showingFinalScore = true
    }
}
// MARK: - Create Flashcard View
struct CreateFlashcardView: View {
    let deck: Deck
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var frontText1 = ""
    @State private var frontText2 = ""
    @State private var backText1 = ""
    @State private var backText2 = ""
    @State private var flashcardID = UUID().uuidString
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Front Side Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Front Side")
                            .font(.headline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            // Text Fields Container
                            VStack(spacing: 8) {
                                TextField("Front text", text: $frontText1)
                                    .textFieldStyle(.plain)
                                    .padding()
                                Divider()
                                    .padding(.leading)
                                TextField("Front secondary text", text: $frontText2)
                                    .textFieldStyle(.plain)
                                    .padding()
                            }
                            .background(Color.white)
                            .cornerRadius(15)
                            
                            // Photo Section
                            VStack(spacing: 12) {
                                FlashcardPhotoView(
                                    flashcardID: flashcardID,
                                    side: "front",
                                    title: "Photo"
                                )
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                            
                            // Audio Section
                            VStack(spacing: 12) {
                                UserDefaultsAudioView(
                                    title: "Audio",
                                    flashcardID: flashcardID,
                                    side: "front"
                                )
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Back Side Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Back Side")
                            .font(.headline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            // Text Fields Container
                            VStack(spacing: 8) {
                                TextField("Back text", text: $backText1)
                                    .textFieldStyle(.plain)
                                    .padding()
                                Divider()
                                    .padding(.leading)
                                TextField("Back secondary text", text: $backText2)
                                    .textFieldStyle(.plain)
                                    .padding()
                            }
                            .background(Color.white)
                            .cornerRadius(15)
                            
                            // Photo Section
                            VStack(spacing: 12) {
                                FlashcardPhotoView(
                                    flashcardID: flashcardID,
                                    side: "back",
                                    title: "Photo"
                                )
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                            
                            // Audio Section
                            VStack(spacing: 12) {
                                UserDefaultsAudioView(
                                    title: "Audio",
                                    flashcardID: flashcardID,
                                    side: "back"
                                )
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground)) // Light grey background
            .navigationTitle("New Flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        FlashAudioManager.shared.deleteAllAudio(flashcardID: flashcardID)
                        FlashPhotoManager.shared.deleteAllPhotos(flashcardID: flashcardID)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFlashcard()
                    }
                    .disabled(frontText1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              backText1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveFlashcard() {
        let newFlashcard = Flashcard(context: viewContext)
        newFlashcard.id = UUID(uuidString: flashcardID)
        newFlashcard.frontText1 = frontText1.trimmingCharacters(in: .whitespacesAndNewlines)
        newFlashcard.frontText2 = frontText2.trimmingCharacters(in: .whitespacesAndNewlines)
        newFlashcard.backText1 = backText1.trimmingCharacters(in: .whitespacesAndNewlines)
        newFlashcard.backText2 = backText2.trimmingCharacters(in: .whitespacesAndNewlines)
        newFlashcard.createdDate = Date()
        newFlashcard.correctStreak = 0
        newFlashcard.needsReview = false
        newFlashcard.deck = deck
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("❌ Error saving flashcard: \(error)")
            FlashAudioManager.shared.deleteAllAudio(flashcardID: flashcardID)
            FlashPhotoManager.shared.deleteAllPhotos(flashcardID: flashcardID)
        }
    }
}
// MARK: - Photo View Component
struct FlashcardPhotoView: View {
    let flashcardID: String
    let side: String
    let title: String
    
    @State private var showingPhotoPicker = false
    @State private var showingCameraPicker = false
    @State private var showingPhotoSourceSelection = false
    @State private var showingFileImporter = false
    @State private var hasPhoto = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .fontDesign(.rounded)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    showingPhotoSourceSelection = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: hasPhoto ? "photo.badge.plus" : "photo.circle.fill")
                            .foregroundColor(.blue)
                        Text(hasPhoto ? "Change" : "Add Photo")
                            .font(.caption)
                            .fixedSize()
                    }
                }
                .buttonStyle(.bordered)
                .clipShape(.capsule)
                
                if hasPhoto {
                    Button(action: {
                        deletePhoto()
                    }) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "trash")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12, weight: .medium))
                            )
                    }
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showingPhotoSourceSelection) {
            Button("Take Photo") {
                showingCameraPicker = true
            }
            Button("Photo Library") {
                showingPhotoPicker = true
            }
            Button("Browse Files") {
                showingFileImporter = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingCameraPicker) {
            CameraPicker(flashcardID: flashcardID, side: side) {
                checkPhotoExists()
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPicker(flashcardID: flashcardID, side: side) {
                checkPhotoExists()
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                importPhotoFile(from: url)
            case .failure(let error):
                print("Error importing photo file: \(error)")
            }
        }
        .onAppear {
            checkPhotoExists()
        }
    }
    
    private func checkPhotoExists() {
        hasPhoto = FlashPhotoManager.shared.hasPhoto(flashcardID: flashcardID, side: side)
    }
    
    private func deletePhoto() {
        FlashPhotoManager.shared.deletePhoto(flashcardID: flashcardID, side: side)
        checkPhotoExists()
    }
    
    private func importPhotoFile(from url: URL) {
        if FlashPhotoManager.shared.savePhoto(from: url, flashcardID: flashcardID, side: side) {
            checkPhotoExists()
        }
    }
}

// MARK: - Camera Picker
struct CameraPicker: UIViewControllerRepresentable {
    let flashcardID: String
    let side: String
    let onPhotoTaken: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.cameraDevice = .rear
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            if let capturedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                // Save image to temporary location first
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_camera_\(UUID().uuidString).jpg")
                
                if let jpegData = capturedImage.jpegData(compressionQuality: 0.8) {
                    do {
                        try jpegData.write(to: tempURL)
                        
                        // Save using photo manager
                        if FlashPhotoManager.shared.savePhoto(from: tempURL, flashcardID: parent.flashcardID, side: parent.side) {
                            parent.onPhotoTaken()
                        }
                        
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempURL)
                    } catch {
                        print("Error saving camera image: \(error)")
                    }
                }
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Photo Picker
struct PhotoPicker: UIViewControllerRepresentable {
    let flashcardID: String
    let side: String
    let onPhotoSelected: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            if let editedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                // Save image to temporary location first
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_photo_\(UUID().uuidString).jpg")
                
                if let jpegData = editedImage.jpegData(compressionQuality: 0.8) {
                    do {
                        try jpegData.write(to: tempURL)
                        
                        // Save using photo manager
                        if FlashPhotoManager.shared.savePhoto(from: tempURL, flashcardID: parent.flashcardID, side: parent.side) {
                            parent.onPhotoSelected()
                        }
                        
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempURL)
                    } catch {
                        print("Error saving image: \(error)")
                    }
                }
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Enhanced Audio Component
struct UserDefaultsAudioView: View {
    let title: String
    let flashcardID: String
    let side: String
    
    @State private var isRecording = false
    @State private var isPlaying = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingAudioPicker = false
    @State private var hasAudio = false
    @State private var audioDelegate: AudioPlayerDelegate?
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .fontDesign(.rounded)
            
            Spacer()
            
            if hasAudio {
                HStack(spacing: 12) {
                    Button(action: {
                        if isPlaying {
                            stopPlayback()
                        } else {
                            playAudio()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                .foregroundColor(isPlaying ? .orange : .green)
                            Text(isPlaying ? "Stop" : "Play")
                                .font(.caption)
                                .fixedSize()
                        }
                    }
                    .buttonStyle(.bordered)
                    .clipShape(.capsule)
                    
                    Button(action: {
                        deleteAudio()
                    }) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "trash")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12, weight: .medium))
                            )
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundColor(isRecording ? .red : .white)
                            Text(isRecording ? "Stop" : "Record")
                                .font(.caption)
                                .fixedSize()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(.capsule)
                    
                    Button(action: {
                        showingAudioPicker = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.circle.fill")
                                .foregroundColor(.blue)
                            Text("Import")
                                .font(.caption)
                                .fixedSize()
                        }
                    }
                    .buttonStyle(.bordered)
                    .clipShape(.capsule)
                }
            }
        }
        .fileImporter(isPresented: $showingAudioPicker, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                importAudio(from: url)
            case .failure(let error):
                print("Error importing audio: \(error)")
            }
        }
        .onAppear {
            checkAudioExists()
        }
    }
    
    private func checkAudioExists() {
        hasAudio = FlashAudioManager.shared.hasAudio(flashcardID: flashcardID, side: side)
    }
    
    private func startRecording() {
        // Stop any existing playback first
        stopPlayback()
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_\(UUID().uuidString).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            
            print("Started recording...")
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        guard let recorder = audioRecorder else { return }
        
        let tempURL = recorder.url
        recorder.stop()
        audioRecorder = nil
        isRecording = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        // Save using UserDefaults system
        if FlashAudioManager.shared.saveAudio(from: tempURL, flashcardID: flashcardID, side: side) {
            checkAudioExists()
        }
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    private func importAudio(from url: URL) {
        // Stop any existing playback first
        stopPlayback()
        
        if FlashAudioManager.shared.saveAudio(from: url, flashcardID: flashcardID, side: side) {
            checkAudioExists()
        }
    }
    
    private func playAudio() {
        // Stop any existing playback first
        stopPlayback()
        
        guard let audioPath = FlashAudioManager.shared.getAudioPath(flashcardID: flashcardID, side: side) else {
            print("No audio path found")
            return
        }
        
        let audioURL = URL(fileURLWithPath: audioPath)
        
        // Check if file actually exists before trying to play
        guard FileManager.default.fileExists(atPath: audioPath) else {
            print("Audio file doesn't exist at path: \(audioPath)")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Set up audio session on background thread
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
                
                // Create player on background thread
                let player = try AVAudioPlayer(contentsOf: audioURL)
                player.prepareToPlay()
                
                // Switch to main thread for UI updates and playback
                DispatchQueue.main.async {
                    self.audioPlayer = player
                    
                    // Create and store delegate
                    self.audioDelegate = AudioPlayerDelegate {
                        DispatchQueue.main.async {
                            self.isPlaying = false
                            self.audioPlayer = nil
                            self.audioDelegate = nil
                            try? AVAudioSession.sharedInstance().setActive(false)
                        }
                    }
                    
                    // Set up delegate to detect when playback finishes
                    self.audioPlayer?.delegate = self.audioDelegate
                    
                    // Start playback
                    if self.audioPlayer?.play() == true {
                        self.isPlaying = true
                        print("Audio playback started successfully")
                    } else {
                        print("Failed to start audio playback")
                        self.stopPlayback()
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    print("Could not play audio: \(error)")
                    self.stopPlayback()
                }
            }
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioDelegate = nil
        isPlaying = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func deleteAudio() {
        stopPlayback()
        FlashAudioManager.shared.deleteAudio(flashcardID: flashcardID, side: side)
        checkAudioExists()
    }
}

// MARK: - Flashcard Detail View
struct FlashcardDetailView: View {
    let flashcard: Flashcard
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var isShowingBack = false
    @State private var frontText1: String
    @State private var frontText2: String
    @State private var backText1: String
    @State private var backText2: String
    @State private var refreshToggle = false
    @State private var refreshTimer: Timer?
    @State private var frontPhotoImage: UIImage?
    @State private var backPhotoImage: UIImage?
    
    private var flashcardID: String {
        flashcard.id?.uuidString ?? "unknown"
    }
    
    init(flashcard: Flashcard) {
        self.flashcard = flashcard
        self._frontText1 = State(initialValue: flashcard.frontText1 ?? "")
        self._frontText2 = State(initialValue: flashcard.frontText2 ?? "")
        self._backText1 = State(initialValue: flashcard.backText1 ?? "")
        self._backText2 = State(initialValue: flashcard.backText2 ?? "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isShowingBack ? "Back" : "Front")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
            
            VStack(spacing: 0) {
                if isShowingBack {
                    backSideContent
                } else {
                    frontSideContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(.systemGray6), Color(.systemGray4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(20)
            .onTapGesture {
                saveChanges()
                withAnimation(.easeInOut(duration: 0.3)) {
                    isShowingBack.toggle()
                }
            }
            
            Text("Tap card to flip")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Flashcard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
            }
        }
        .onAppear {
            startRefreshTimer()
            refreshPhotos()
        }
        .onDisappear {
            stopRefreshTimer()
            saveChanges()
        }
        .onChange(of: refreshToggle) { _ in
            refreshPhotos()
        }
    }
    
    private var frontSideContent: some View {
        VStack(spacing: 0) {
            // Conditional layout based on photo presence
            if let image = frontPhotoImage {
                // Layout with photo - move image and text upward together
                VStack(spacing: 16) {
                    // Small spacer to move content up from top
                    Spacer()
                        .frame(height: 40)
                    
                    // Photo positioned higher
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(16)
                    
                    // Text directly below photo
                    VStack(spacing: 12) {
                        TextField("Front text 1", text: $frontText1)
                            .font(.title2.weight(.bold))
                            .fontDesign(.rounded)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !frontText2.isEmpty {
                            TextField("Front text 2", text: $frontText2)
                                .font(.body.weight(.medium))
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                    }
                    
                    Spacer()
                    
                    // Controls at bottom
                    VStack(spacing: 12) {
                        FlashcardPhotoView(
                            flashcardID: flashcardID,
                            side: "front",
                            title: "Front Photo"
                        )
                        
                        UserDefaultsAudioView(
                            title: "Front Audio",
                            flashcardID: flashcardID,
                            side: "front"
                        )
                    }
                    .padding(.bottom, 10)
                }
            } else {
                // Layout without photo - text centered vertically
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Centered text when no photo
                    VStack(spacing: 12) {
                        TextField("Front text 1", text: $frontText1)
                            .font(.title2.weight(.bold))
                            .fontDesign(.rounded)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !frontText2.isEmpty {
                            TextField("Front text 2", text: $frontText2)
                                .font(.body.weight(.medium))
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                    }
                    
                    Spacer()
                    
                    // Controls at bottom
                    VStack(spacing: 12) {
                        FlashcardPhotoView(
                            flashcardID: flashcardID,
                            side: "front",
                            title: "Front Photo"
                        )
                        
                        UserDefaultsAudioView(
                            title: "Front Audio",
                            flashcardID: flashcardID,
                            side: "front"
                        )
                    }
                    .padding(.bottom, 10)
                }
            }
        }
    }
    
    private var backSideContent: some View {
        VStack(spacing: 0) {
            // Conditional layout based on photo presence
            if let image = backPhotoImage {
                // Layout with photo - move image and text upward together
                VStack(spacing: 16) {
                    // Small spacer to move content up from top
                    Spacer()
                        .frame(height: 40)
                    
                    // Photo positioned higher
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(16)
                    
                    // Text directly below photo
                    VStack(spacing: 12) {
                        TextField("Back text 1", text: $backText1)
                            .font(.title2.weight(.bold))
                            .fontDesign(.rounded)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !backText2.isEmpty {
                            TextField("Back text 2", text: $backText2)
                                .font(.body.weight(.medium))
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                    }
                    
                    Spacer()
                    
                    // Controls at bottom
                    VStack(spacing: 12) {
                        FlashcardPhotoView(
                            flashcardID: flashcardID,
                            side: "back",
                            title: "Back Photo"
                        )
                        
                        UserDefaultsAudioView(
                            title: "Back Audio",
                            flashcardID: flashcardID,
                            side: "back"
                        )
                    }
                    .padding(.bottom, 10)
                }
            } else {
                // Layout without photo - text centered vertically
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Centered text when no photo
                    VStack(spacing: 12) {
                        TextField("Back text 1", text: $backText1)
                            .font(.title2.weight(.bold))
                            .fontDesign(.rounded)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !backText2.isEmpty {
                            TextField("Back text 2", text: $backText2)
                                .font(.body.weight(.medium))
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                    }
                    
                    Spacer()
                    
                    // Controls at bottom
                    VStack(spacing: 12) {
                        FlashcardPhotoView(
                            flashcardID: flashcardID,
                            side: "back",
                            title: "Back Photo"
                        )
                        
                        UserDefaultsAudioView(
                            title: "Back Audio",
                            flashcardID: flashcardID,
                            side: "back"
                        )
                    }
                    .padding(.bottom, 10)
                }
            }
        }
    }
    
    private func saveChanges() {
        flashcard.frontText1 = frontText1
        flashcard.frontText2 = frontText2
        flashcard.backText1 = backText1
        flashcard.backText2 = backText2
        
        do {
            try viewContext.save()
            print("✅ Flashcard text saved")
        } catch {
            print("❌ Error saving flashcard: \(error)")
        }
    }
    
    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            refreshToggle.toggle()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func refreshPhotos() {
        // Check and load front photo
        if FlashPhotoManager.shared.hasPhoto(flashcardID: flashcardID, side: "front"),
           let frontPath = FlashPhotoManager.shared.getPhotoPath(flashcardID: flashcardID, side: "front") {
            frontPhotoImage = UIImage(contentsOfFile: frontPath)
        } else {
            frontPhotoImage = nil
        }
        
        // Check and load back photo
        if FlashPhotoManager.shared.hasPhoto(flashcardID: flashcardID, side: "back"),
           let backPath = FlashPhotoManager.shared.getPhotoPath(flashcardID: flashcardID, side: "back") {
            backPhotoImage = UIImage(contentsOfFile: backPath)
        } else {
            backPhotoImage = nil
        }
    }
}
// MARK: - Study Mode View
struct StudyModeView: View {
    let deck: Deck
    let reviewMode: Bool
    var reviewCards: [Flashcard] = []
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentCardIndex = 0
    @State private var isShowingBack = false
    @State private var studyCards: [Flashcard] = []
    @State private var showingReviewPrompt = false
    @State private var remainingReviewCards: [Flashcard] = []
    @State private var studyingReviewCards = false
    @State private var showingCompletionAlert = false
    @State private var completionMessage = ""
    @State private var hasReviewCardsAvailable = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if studyCards.isEmpty {
                    completionView
                } else {
                    progressHeaderView
                    studyCardDisplayView
                    instructionTextView
                    actionButtonsView
                }
                
                Spacer()
            }
            .navigationTitle(reviewMode || studyingReviewCards ? "Review Mode" : "Study Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupStudySession()
            // Start timing for first card
            if !studyCards.isEmpty {
                let firstCardID = studyCards[0].id?.uuidString ?? "unknown"
                SpacedRepetitionManager.shared.startTimer(for: firstCardID)
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 20) {
            // Check if this is a deck mastery completion
            if completionMessage.contains("mastered") {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold color
                
                Text("Deck Mastered!")
                    .font(.title.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundColor(.primary)
                
                Text("🎉 Congratulations! 🎉")
                    .font(.title2.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundColor(.green)
                
                Text("You've mastered this entire deck!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Study Session Complete!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                
                Text(completionMessage)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Show review option if cards need review (only for regular study mode)
            if hasReviewCardsAvailable && !reviewMode && !studyingReviewCards {
                VStack(spacing: 16) {
                    Text("Some cards need more review")
                        .font(.headline)
                        .fontDesign(.rounded)
                        .foregroundColor(.orange)
                    
                    HStack(spacing: 16) {
                        Button("Finish") {
                            checkDeckMastery()
                        }
                        .font(.body.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                        
                        Button("Review Cards") {
                            startReviewMode()
                        }
                        .font(.body.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                }
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Auto-dismiss logic
            if completionMessage.contains("mastered") {
                // Deck mastered - longer celebration time
                return // Don't auto-dismiss, handled in checkDeckMastery
            } else if !hasReviewCardsAvailable && !reviewMode && !studyingReviewCards {
                // Regular completion with no review cards
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            // If in review mode or has review cards, wait for user action
        }
    }
    
    private var progressHeaderView: some View {
        HStack {
            Text("\(currentCardIndex + 1) of \(studyCards.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if reviewMode || studyingReviewCards {
                Text("Review Mode")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal)
    }
    
    private var studyCardDisplayView: some View {
        let currentCard = studyCards[currentCardIndex]
        let currentCardID = currentCard.id?.uuidString ?? "unknown"
        
        return VStack(spacing: 0) {
            if isShowingBack {
                // Back side content with improved layout
                if FlashPhotoManager.shared.hasPhoto(flashcardID: currentCardID, side: "back"),
                   let photoPath = FlashPhotoManager.shared.getPhotoPath(flashcardID: currentCardID, side: "back"),
                   let image = UIImage(contentsOfFile: photoPath) {
                    // Layout with photo - center image and text together
                    VStack(spacing: 0) {
                        Text("Back")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top)
                        
                        Spacer()
                        
                        VStack(spacing: 20) {
                            // Image centered
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 180)
                                .cornerRadius(16)
                            
                            // Text centered below image
                            VStack(spacing: 8) {
                                Text(currentCard.backText1 ?? "")
                                    .font(.title2.weight(.bold))
                                    .fontDesign(.rounded)
                                    .multilineTextAlignment(.center)
                                if let backText2 = currentCard.backText2, !backText2.isEmpty {
                                    Text(backText2)
                                        .font(.body.weight(.medium))
                                        .fontDesign(.rounded)
                                        .multilineTextAlignment(.center)
                                }
                                
                                if FlashAudioManager.shared.hasAudio(flashcardID: currentCardID, side: "back") {
                                    StudyAudioPlayer(flashcardID: currentCardID, side: "back", label: "🔊 Back Audio")
                                }
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    // Layout without photo - text centered vertically
                    VStack(spacing: 0) {
                        Text("Back")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top)
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Text(currentCard.backText1 ?? "")
                                .font(.title2.weight(.bold))
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                            if let backText2 = currentCard.backText2, !backText2.isEmpty {
                                Text(backText2)
                                    .font(.body.weight(.medium))
                                    .fontDesign(.rounded)
                                    .multilineTextAlignment(.center)
                            }
                            
                            if FlashAudioManager.shared.hasAudio(flashcardID: currentCardID, side: "back") {
                                StudyAudioPlayer(flashcardID: currentCardID, side: "back", label: "🔊 Back Audio")
                            }
                        }
                        
                        Spacer()
                    }
                }
            } else {
                // Front side content with improved layout
                if FlashPhotoManager.shared.hasPhoto(flashcardID: currentCardID, side: "front"),
                   let photoPath = FlashPhotoManager.shared.getPhotoPath(flashcardID: currentCardID, side: "front"),
                   let image = UIImage(contentsOfFile: photoPath) {
                    // Layout with photo - center image and text together
                    VStack(spacing: 0) {
                        Text("Front")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top)
                        
                        Spacer()
                        
                        VStack(spacing: 20) {
                            // Image centered
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 180)
                                .cornerRadius(16)
                            
                            // Text centered below image
                            VStack(spacing: 8) {
                                Text(currentCard.frontText1 ?? "")
                                    .font(.title2.weight(.bold))
                                    .fontDesign(.rounded)
                                    .multilineTextAlignment(.center)
                                if let frontText2 = currentCard.frontText2, !frontText2.isEmpty {
                                    Text(frontText2)
                                        .font(.body.weight(.medium))
                                        .fontDesign(.rounded)
                                        .multilineTextAlignment(.center)
                                }
                                
                                if FlashAudioManager.shared.hasAudio(flashcardID: currentCardID, side: "front") {
                                    StudyAudioPlayer(flashcardID: currentCardID, side: "front", label: "🔊 Front Audio")
                                }
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    // Layout without photo - text centered vertically
                    VStack(spacing: 0) {
                        Text("Front")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top)
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Text(currentCard.frontText1 ?? "")
                                .font(.title2.weight(.bold))
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                            if let frontText2 = currentCard.frontText2, !frontText2.isEmpty {
                                Text(frontText2)
                                    .font(.body.weight(.medium))
                                    .fontDesign(.rounded)
                                    .multilineTextAlignment(.center)
                            }
                            
                            if FlashAudioManager.shared.hasAudio(flashcardID: currentCardID, side: "front") {
                                StudyAudioPlayer(flashcardID: currentCardID, side: "front", label: "🔊 Front Audio")
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            LinearGradient(
                colors: [Color(.systemGray6), Color(.systemGray4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isShowingBack.toggle()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 50 {
                        // Swipe right - mark correct
                        withAnimation {
                            markCorrect()
                        }
                    } else if value.translation.width < -50 {
                        // Swipe left - mark incorrect
                        withAnimation {
                            markIncorrect()
                        }
                    }
                }
        )
    }
    
    private var instructionTextView: some View {
        Text("Tap card to flip • Swipe right for correct • Swipe left for incorrect")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 20) {
            Button(action: {
                withAnimation {
                    markIncorrect()
                }
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Incorrect")
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            
            Button(action: {
                withAnimation {
                    markCorrect()
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Correct")
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }
    
    private func setupStudySession() {
        if reviewMode {
            studyCards = reviewCards.isEmpty ? deck.flashcardsArray.filter { $0.needsReview }.shuffled() : reviewCards.shuffled()
            studyingReviewCards = true
            completionMessage = "You've finished reviewing the missed cards!"
        } else {
            studyCards = deck.flashcardsArray.shuffled()
            studyingReviewCards = false
            completionMessage = "Great job studying!"
        }
        
        currentCardIndex = 0
        isShowingBack = false
    }
    
    private func markCorrect() {
        let currentCard = studyCards[currentCardIndex]
        let cardID = currentCard.id?.uuidString ?? "unknown"
        
        // End timing
        SpacedRepetitionManager.shared.endTimer(for: cardID)
        
        currentCard.correctStreak += 1
        
        if (reviewMode || studyingReviewCards) && currentCard.correctStreak >= 3 {
            currentCard.needsReview = false
        }
        
        nextCard()
    }
    
    private func markIncorrect() {
        let currentCard = studyCards[currentCardIndex]
        let cardID = currentCard.id?.uuidString ?? "unknown"
        
        // End timing
        SpacedRepetitionManager.shared.endTimer(for: cardID)
        
        currentCard.needsReview = true
        currentCard.correctStreak = 0
        
        nextCard()
    }
    
    private func nextCard() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving card progress: \(error)")
        }
        
        if currentCardIndex < studyCards.count - 1 {
            currentCardIndex += 1
            isShowingBack = false
            
            // Start timing for next card
            let nextCard = studyCards[currentCardIndex]
            let nextCardID = nextCard.id?.uuidString ?? "unknown"
            SpacedRepetitionManager.shared.startTimer(for: nextCardID)
        } else {
            finishStudySession()
        }
    }
    
    private func finishStudySession() {
        if reviewMode {
            checkDeckMastery()
        } else if studyingReviewCards {
            checkDeckMastery()
        } else {
            remainingReviewCards = deck.flashcardsArray.filter { $0.needsReview }
            if !remainingReviewCards.isEmpty {
                // Set flag to show review option on completion screen
                hasReviewCardsAvailable = true
                studyCards.removeAll() // This will trigger the completion view
            } else {
                // No review cards needed - show completion and auto-dismiss
                hasReviewCardsAvailable = false
                studyCards.removeAll()
            }
        }
    }
    
    private func startReviewMode() {
        studyCards = remainingReviewCards.shuffled()
        studyingReviewCards = true
        currentCardIndex = 0
        isShowingBack = false
        completionMessage = "You've finished reviewing the missed cards!"
        
        // Start timing for first review card
        if !studyCards.isEmpty {
            let firstCardID = studyCards[0].id?.uuidString ?? "unknown"
            SpacedRepetitionManager.shared.startTimer(for: firstCardID)
        }
    }
    
    private func checkDeckMastery() {
        let allCardsMastered = deck.flashcardsArray.allSatisfy { card in
            !card.needsReview && card.correctStreak >= 3
        }
        
        if allCardsMastered && !deck.flashcardsArray.isEmpty {
            deck.isMastered = true
            do {
                try viewContext.save()
                // Show mastery completion screen instead of popup
                completionMessage = "Congratulations! You've mastered this deck!"
                studyCards.removeAll() // Show completion view
                
                // Auto-dismiss after celebrating
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("Error updating deck mastery: \(error)")
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
// MARK: - Study Audio Player
struct StudyAudioPlayer: View {
    let flashcardID: String
    let side: String
    let label: String
    
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioDelegate: AudioPlayerDelegate?
    
    var body: some View {
        Button(action: {
            if isPlaying {
                stopPlayback()
            } else {
                playAudio()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .foregroundColor(isPlaying ? .orange : .blue)
                Text(isPlaying ? "Stop" : label)
                    .font(.caption)
                    .fontDesign(.rounded)
            }
        }
        .buttonStyle(BorderedButtonStyle())
    }
    
    private func playAudio() {
        // Stop any existing playback first
        stopPlayback()
        
        guard let audioPath = FlashAudioManager.shared.getAudioPath(flashcardID: flashcardID, side: side) else {
            print("No audio found for \(flashcardID)_\(side)")
            return
        }
        
        let audioURL = URL(fileURLWithPath: audioPath)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: audioPath) else {
            print("Audio file doesn't exist")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Set up audio session on background thread
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
                
                // Create player on background thread
                let player = try AVAudioPlayer(contentsOf: audioURL)
                player.prepareToPlay()
                
                // Switch to main thread for UI updates and playback
                DispatchQueue.main.async {
                    self.audioPlayer = player
                    
                    // Create and store delegate
                    self.audioDelegate = AudioPlayerDelegate {
                        DispatchQueue.main.async {
                            self.isPlaying = false
                            self.audioPlayer = nil
                            self.audioDelegate = nil
                            try? AVAudioSession.sharedInstance().setActive(false)
                        }
                    }
                    
                    // Set up delegate
                    self.audioPlayer?.delegate = self.audioDelegate
                    
                    // Start playback
                    if self.audioPlayer?.play() == true {
                        self.isPlaying = true
                        print("Playing audio: \(audioPath)")
                    } else {
                        print("Failed to start playback")
                        self.stopPlayback()
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    print("Could not play audio: \(error)")
                    self.stopPlayback()
                }
            }
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioDelegate = nil
        isPlaying = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - Persistence Controller
struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FlashcardModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Extensions for Core Data
extension Deck {
    public var flashcardsArray: [Flashcard] {
        let set = flashcards as? Set<Flashcard> ?? []
        return set.sorted { ($0.createdDate ?? Date()) < ($1.createdDate ?? Date()) }
    }
}

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
