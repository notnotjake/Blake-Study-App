//
//  TestNewWordInteraction.swift
//  WordScramble
//
//  Created by Jake Go on 7/12/24.
//

import SwiftUI
import UIKit

struct DictionaryLookup: UIViewControllerRepresentable {
    let word: String
    
    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        return UIReferenceLibraryViewController(term: word)
    }
    
    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}

struct HSBColor {
    let hue: Double
    let saturation: Double
    let brightness: Double
    
    var color: Color {
        Color(hue: hue / 360.0, saturation: saturation / 100.0, brightness: brightness / 100.0 )
    }
}

struct TestNewWordInteraction: View {
    @Binding var rootWord: String
    @State private var lastWord: String = ""
    @State private var nextWord: String = ""
    
    @State private var isDragged = false
    @State private var dragAmount = CGSize.zero
    @State private var rotationAngle: Angle = Angle(degrees: 0)
    var dragTolerance = 30.0
    
    @State private var isShowingDictionaryLookup = false
    
    var body: some View {
        ZStack {
            if isDragged {
                HStack {
                    if !lastWord.isEmpty {
                        Image(systemName: "arrowshape.backward.fill")
                            .foregroundStyle(
                                dragAmount.width < (-1 * dragTolerance)
                                ? HSBColor(hue: 200, saturation: 90, brightness: 98).color
                                : .gray.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: nextWord.isEmpty ? "arrow.clockwise.circle.fill" : "arrowshape.forward.fill")
                        .foregroundStyle(
                            dragAmount.width > dragTolerance
                                ? HSBColor(hue: 200, saturation: 90, brightness: 98).color
                                : .gray.opacity(0.7))
                }
                .font(.largeTitle)
                .padding(.horizontal, 20)
            }
            
            Text("\(rootWord)".uppercased())
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .padding(.vertical, 5)
                .padding(.horizontal, 20)
                .background(.thinMaterial.opacity(isDragged ? 1.0 : 0.0))
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .onAppear(perform: seedWord)
                .onTapGesture {
                    seedWord()
                }
                .rotationEffect(rotationAngle)
                .offset(dragAmount)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragAmount.width = value.translation.width
                            dragAmount.height = 30 * log(abs(value.translation.height) / 30 + 1) * (value.translation.height < 0 ? -1 : 1)
                            rotationAngle = Angle(degrees: value.translation.width / 20)
                            
                            withAnimation(.easeIn(duration: 0.15)) {
                                isDragged = true
                            }
                        }
                        .onEnded { value in
                            // Go Back
                            if dragAmount.width < (-1 * dragTolerance) && !lastWord.isEmpty {
                                nextWord = rootWord
                                rootWord = lastWord
                                lastWord = ""
                            }
                            // Go Forward (after going back)
                            else if dragAmount.width > dragTolerance && !nextWord.isEmpty {
                                lastWord = rootWord
                                rootWord = nextWord
                                nextWord = ""
                            }
                            else if dragAmount.width > dragTolerance {
                                seedWord()
                            }
                            else {
                                // do nothing
                            }
                            
                            withAnimation(.bouncy(duration: 0.35)) {
                                dragAmount = .zero
                                rotationAngle = Angle(degrees: 0)
                                isDragged = false
                            }
                        }
                )
                .contextMenu {
                    Button{
                        seedWord()
                    } label: {
                        Label("Get New Word", systemImage: "arrow.clockwise.circle.fill")
                    }
                    Divider()
                    Button{
                        isShowingDictionaryLookup = true
                    } label: {
                        Label("Look Up", systemImage: "magnifyingglass")
                    }
                    Button {
                        // add to saved words list
                    } label: {
                        Label("Save Word", systemImage: "square.and.arrow.down")
                    }
                }
                .sheet(isPresented: $isShowingDictionaryLookup) {
                    DictionaryLookup(word: rootWord)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: 50)
    }
    
    func seedWord () {
        if !rootWord.isEmpty {
            lastWord = rootWord
        }
        rootWord = "MOTORWAY"
    }
}

#Preview {
    TestNewWordInteraction(rootWord: .constant("TEST"))
}
