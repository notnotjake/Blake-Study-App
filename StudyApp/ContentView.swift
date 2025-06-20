//
//  ContentView.swift
//  StudyApp - Complete Fixed Version with Audio Fix
//

import SwiftUI
import CoreData
import AVFoundation
import UniformTypeIdentifiers

import MCEmojiPicker

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
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(decks, id: \.self) { deck in
                            NavigationLink(destination: DeckPageView(deck: deck)) {
                                DeckRowView(deck: deck)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Study Decks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
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
        .onAppear {
            FlashAudioManager.shared.syncAudioData()
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

// MARK: - Deck Row View
struct DeckRowView: View {
    let deck: Deck
    @State private var refreshToggle = false
    @State private var refreshTimer: Timer?
    
    var body: some View {
        HStack(spacing: 16) {
            Text(deck.emoji ?? "📚")
                .font(.system(size: 40))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name ?? "Untitled Deck")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(deck.flashcardsArray.count) cards")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if deck.isMastered {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            startRowRefreshTimer()
        }
        .onDisappear {
            stopRowRefreshTimer()
        }
        .onChange(of: refreshToggle) { _ in }
    }
    
    private func startRowRefreshTimer() {
        stopRowRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            refreshToggle.toggle()
        }
    }
    
    private func stopRowRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
    @State private var refreshToggle = false
    @State private var refreshTimer: Timer?
    
    private var cardsNeedingReview: [Flashcard] {
        deck.flashcardsArray.filter { $0.needsReview }
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
                        .foregroundColor(.gray)
                    Text("Tap the + button to add your first flashcard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(deck.flashcardsArray, id: \.self) { flashcard in
                            NavigationLink(destination: FlashcardDetailView(flashcard: flashcard)) {
                                FlashcardRowView(flashcard: flashcard)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                VStack(spacing: 12) {
                    if isDeckMastered {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Deck Mastered!")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        
                        Button(action: {
                            showingStudyMode = true
                        }) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text("Study Again")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    } else if hasCardsToReview {
                        HStack(spacing: 12) {
                            Button(action: {
                                showingStudyMode = true
                            }) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                    Text("Study All")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingReviewMode = true
                            }) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("Review (\(cardsNeedingReview.count))")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                        }
                    } else {
                        Button(action: {
                            showingStudyMode = true
                        }) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text("Study Now")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
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
                Button(action: {
                    showingCreateFlashcard = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
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
            StudyModeView(deck: deck, reviewMode: true)
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

// MARK: - Flashcard Row View
struct FlashcardRowView: View {
    let flashcard: Flashcard
    @State private var refreshToggle = false
    @State private var refreshTimer: Timer?
    
    private var flashcardID: String {
        flashcard.id?.uuidString ?? "unknown"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Front")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(flashcard.frontText1 ?? "")
                        .font(.body)
                        .lineLimit(2)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    if FlashAudioManager.shared.hasAudio(flashcardID: flashcardID, side: "front") {
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
                        .font(.body)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if FlashAudioManager.shared.hasAudio(flashcardID: flashcardID, side: "back") {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .onChange(of: refreshToggle) { _ in }
    }
    
    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            refreshToggle.toggle()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Front Side")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
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
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(15)
                        }
                        
                        VStack {
                            UserDefaultsAudioView(
                                title: "Audio",
                                flashcardID: flashcardID,
                                side: "front"
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Back Side")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
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
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(15)
                        }
                        
                        VStack {
                            UserDefaultsAudioView(
                                title: "Audio",
                                flashcardID: flashcardID,
                                side: "back"
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("New Flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        FlashAudioManager.shared.deleteAllAudio(flashcardID: flashcardID)
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
        }
    }
}

// MARK: - FIXED UserDefaults Audio Component
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
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
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
                
                if hasAudio {
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
                        }
                    }
                    .buttonStyle(BorderedButtonStyle())
                    
                    Button(action: {
                        deleteAudio()
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
            }
            
            if hasAudio {
                Text("Audio: \(flashcardID)_\(side).m4a")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
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
    
    // FIXED AUDIO PLAYBACK - No more freezing
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
            
            VStack(spacing: 16) {
                if isShowingBack {
                    VStack(spacing: 12) {
                        TextField("Back text 1", text: $backText1)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !backText2.isEmpty {
                            TextField("Back text 2", text: $backText2)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        UserDefaultsAudioView(
                            title: "Back Audio",
                            flashcardID: flashcardID,
                            side: "back"
                        )
                    }
                } else {
                    VStack(spacing: 12) {
                        TextField("Front text 1", text: $frontText1)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !frontText2.isEmpty {
                            TextField("Front text 2", text: $frontText2)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        UserDefaultsAudioView(
                            title: "Front Audio",
                            flashcardID: flashcardID,
                            side: "front"
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
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
        .onDisappear {
            saveChanges()
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
}

// MARK: - Study Mode View
struct StudyModeView: View {
    let deck: Deck
    let reviewMode: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentCardIndex = 0
    @State private var isShowingBack = false
    @State private var studyCards: [Flashcard] = []
    @State private var showingReviewPrompt = false
    @State private var reviewCards: [Flashcard] = []
    @State private var studyingReviewCards = false
    @State private var showingCompletionAlert = false
    @State private var completionMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if studyCards.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Study Session Complete!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(completionMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
                    
                    let currentCard = studyCards[currentCardIndex]
                    let currentCardID = currentCard.id?.uuidString ?? "unknown"
                    
                    VStack(spacing: 16) {
                        Text(isShowingBack ? "Back" : "Front")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 12) {
                            if isShowingBack {
                                Text(currentCard.backText1 ?? "")
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                if let backText2 = currentCard.backText2, !backText2.isEmpty {
                                    Text(backText2)
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                }
                                
                                if FlashAudioManager.shared.hasAudio(flashcardID: currentCardID, side: "back") {
                                    StudyAudioPlayer(flashcardID: currentCardID, side: "back", label: "🔊 Back Audio")
                                }
                            } else {
                                Text(currentCard.frontText1 ?? "")
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                if let frontText2 = currentCard.frontText2, !frontText2.isEmpty {
                                    Text(frontText2)
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                }
                                
                                if FlashAudioManager.shared.hasAudio(flashcardID: currentCardID, side: "front") {
                                    StudyAudioPlayer(flashcardID: currentCardID, side: "front", label: "🔊 Front Audio")
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowingBack.toggle()
                        }
                    }
                    
                    Text("Tap card to flip")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            markIncorrect()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Incorrect")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            markCorrect()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Correct")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
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
        }
        .alert("Review More Cards?", isPresented: $showingReviewPrompt) {
            Button("Yes") {
                startReviewMode()
            }
            Button("No") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Would you like to review cards that need further review?")
        }
        .alert("Deck Mastered!", isPresented: $showingCompletionAlert) {
            Button("Great!") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Congratulations! You've mastered this deck!")
        }
    }
    
    private func setupStudySession() {
        if reviewMode {
            studyCards = deck.flashcardsArray.filter { $0.needsReview }.shuffled()
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
        currentCard.correctStreak += 1
        
        if (reviewMode || studyingReviewCards) && currentCard.correctStreak >= 3 {
            currentCard.needsReview = false
        }
        
        nextCard()
    }
    
    private func markIncorrect() {
        let currentCard = studyCards[currentCardIndex]
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
            reviewCards = deck.flashcardsArray.filter { $0.needsReview }
            if !reviewCards.isEmpty {
                showingReviewPrompt = true
            } else {
                checkDeckMastery()
            }
        }
    }
    
    private func startReviewMode() {
        studyCards = reviewCards.shuffled()
        studyingReviewCards = true
        currentCardIndex = 0
        isShowingBack = false
        completionMessage = "You've finished reviewing the missed cards!"
    }
    
    private func checkDeckMastery() {
        let allCardsMastered = deck.flashcardsArray.allSatisfy { card in
            !card.needsReview && card.correctStreak >= 3
        }
        
        if allCardsMastered && !deck.flashcardsArray.isEmpty {
            deck.isMastered = true
            do {
                try viewContext.save()
                showingCompletionAlert = true
            } catch {
                print("Error updating deck mastery: \(error)")
            }
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - FIXED Study Audio Player
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

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
