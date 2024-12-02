//
//  ContentView.swift
//  LanternMapEditor
//
//  Created by Brian Babbitt on 11/29/24.
//

import Foundation
import SwiftUI
import AppKit

struct TileView: View {
    let image: NSImage
    let tileSize: CGSize = CGSize(width: 32, height: 32)
    @State private var placedTiles: [(image: NSImage, position: CGPoint)] = [] // Track placed tiles
    @State private var draggingTile: NSImage? = nil // Tile currently being dragged
    @State private var draggingPosition: CGPoint = .zero // Position of the dragged tile
    @State private var hoveredTileIndex: Int? = nil // Track the hovered tile
    @State private var showPopoverForTile: Int? = nil // Track the tile for which the popover is shown
    @State private var foregroundTiles: Set<Int> = [] // Set to track foreground tiles
    
    var body: some View {
        HStack {
            // Tile Picker Grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                    ForEach(extractTiles(from: image, tileSize: tileSize).indices, id: \.self) { index in
                        VStack(spacing: 4) {
                            let tile = extractTiles(from: image, tileSize: tileSize)[index]
                            Image(nsImage: tile)
                                .resizable()
                                .frame(width: tileSize.width, height: tileSize.height)
                                .border(
                                    hoveredTileIndex == index ? Color.blue : Color.gray, // Blue outline on hover
                                    width: 2
                                )
                                .onHover { isHovering in
                                    hoveredTileIndex = isHovering ? index : nil // Update hover state
                                }
                                .onDrag {
                                    self.draggingTile = tile
                                    return NSItemProvider(object: tile)
                                }
                                .padding(.top, 2)
                                .onTapGesture {
                                    // Detect if the Option key is pressed
                                    if NSEvent.modifierFlags.contains(.option) {
                                        showPopoverForTile = index // Show the popover for this tile
                                    }
                                }
//                                .popover(item: $showPopoverForTile) { index in
//                                    TilePopover(tileIndex: index, foregroundTiles: $foregroundTiles)
//                                }
                            Text("\(index + 1)")
                                .font(.caption)
                        }
                    }
                }
                .padding()
            }
            .frame(width: 200)
            
            Divider()
            
            // Workspace Grid
            VStack {
                Spacer().frame(height: 16)
                ZStack {
                    GeometryReader { geometry in
                        let columns = Int(geometry.size.width / tileSize.width)
                        let rows = Int(geometry.size.height / tileSize.height)
                        
                        // Draw grid
                        ForEach(0..<rows, id: \.self) { row in
                            ForEach(0..<columns, id: \.self) { col in
                                Rectangle()
                                    .stroke(Color.gray, lineWidth: 1)
                                    .frame(width: tileSize.width+2, height: tileSize.height+2)
                                    .position(
                                        CGPoint(
                                            x: CGFloat(col) * tileSize.width + tileSize.width / 2,
                                            y: CGFloat(row) * tileSize.height + tileSize.height / 2
                                        )
                                    )
                            }
                        }
                        
                        // Draw placed tiles
                        ForEach(placedTiles.indices, id: \.self) { index in
                            let tile = placedTiles[index]
                            Image(nsImage: tile.image)
                                .resizable()
                                .frame(width: tileSize.width, height: tileSize.height)
                                .position(tile.position)
                        }
                        
                        // Handle dragging tile
                        if let draggingTile = draggingTile {
                            Image(nsImage: draggingTile)
                                .resizable()
                                .frame(width: tileSize.width, height: tileSize.height)
                                .position(draggingPosition)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            self.draggingPosition = value.location
                                        }
                                        .onEnded { value in
                                            // Snap to nearest grid position
                                            let gridX = round(value.location.x / tileSize.width) * tileSize.width + tileSize.width / 2
                                            let gridY = round(value.location.y / tileSize.height) * tileSize.height + tileSize.height / 2
                                            let snappedPosition = CGPoint(x: gridX, y: gridY)
                                            
                                            
                                            if !placedTiles.contains(where: { $0.position == snappedPosition }) {
                                            self.placedTiles.append((image: draggingTile, position: snappedPosition))
                                            }
                                            self.draggingTile = nil
                                        }
                                )
                        }
                    }
                }
            }
        }
    }
    
    func extractTiles(from image: NSImage, tileSize: CGSize) -> [NSImage] {
        var tiles: [NSImage] = []
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let rows = Int(image.size.height / tileSize.height)
        let columns = Int(image.size.width / tileSize.width)
        
        for row in 0..<rows {
            for col in 0..<columns {
                let x = CGFloat(col) * tileSize.width
                let y = CGFloat(row) * tileSize.height
                let rect = CGRect(x: x, y: y, width: tileSize.width, height: tileSize.height)
                
                if let tileCGImage = cgImage.cropping(to: rect) {
                    let tileNSImage = NSImage(cgImage: tileCGImage, size: tileSize)
                    tiles.append(tileNSImage)
                }
            }
        }
        return tiles
    }
}

struct TilePopover: View {
    let tileIndex: Int
    @Binding var foregroundTiles: Set<Int>
    
    var body: some View {
        VStack {
            Text("Tile Options")
                .font(.headline)
            Toggle("Set as Foreground Tile", isOn: Binding(
                get: { foregroundTiles.contains(tileIndex) },
                set: { newValue in
                    if newValue {
                        foregroundTiles.insert(tileIndex)
                    } else {
                        foregroundTiles.remove(tileIndex)
                    }
                }
            ))
            .padding()
        }
        .frame(width: 200, height: 100)
    }
}

struct ContentView: View {
    var body: some View {
        if let image = NSImage(named: "lantern_tileset_2_sheet") { // Replace "example" with your PNG name in the assets
            TileView(image: image)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            print("Export Map button clicked")
                        }) {
                            Label("Export Map", systemImage: "square.and.arrow.down")
                        }
                        .help("Export Map")
                    }
                    ToolbarItem(placement: .automatic) {
                        Button(action: {
                            print("Settings tapped")
                        }) {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .help("Help me")
                    }
                }
        } else {
            Text("Image not found")
                .foregroundColor(.red)
        }
    }
}

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

//struct TileView: View {
//    let image: NSImage
//    let tileSize: CGSize = CGSize(width: 32, height: 32)
//    
//    var body: some View {
//        let tiles = extractTiles(from: image, tileSize: tileSize)
//        let columns = Int(image.size.width / tileSize.width)
//        
//        ScrollView {
//            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) {
//                ForEach(tiles.indices, id: \.self) { index in
//                    VStack(spacing: 4) {
//                        Image(nsImage: tiles[index])
//                            .resizable()
//                            .frame(width: tileSize.width, height: tileSize.height)
//                            .border(Color.gray)
//                            .padding(.top, 16)
//                        Text("\(index + 1)")
//                            .font(.caption)
//                            
//                    }
//                }
//            }
//            .padding()
//        }
//    }
//    
//    func extractTiles(from image: NSImage, tileSize: CGSize) -> [NSImage] {
//        var tiles: [NSImage] = []
//        
//        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
//        let rows = Int(image.size.height / tileSize.height)
//        let columns = Int(image.size.width / tileSize.width)
//        
//        for row in 0..<rows {
//            for col in 0..<columns {
//                let x = CGFloat(col) * tileSize.width
//                let y = CGFloat(row) * tileSize.height
//                let rect = CGRect(x: x, y: y, width: tileSize.width, height: tileSize.height)
//                
//                if let tileCGImage = cgImage.cropping(to: rect) {
//                    let tileNSImage = NSImage(cgImage: tileCGImage, size: tileSize.size)
//                    tiles.append(tileNSImage)
//                }
//            }
//        }
//        return tiles
//    }
//}
//
//struct ContentView: View {
//    var body: some View {
//        if let image = NSImage(named: "lantern_tileset_2_sheet") { // Replace "example" with your PNG name in the assets
//            TileView(image: image)
//        } else {
//            Text("Image not found")
//                .foregroundColor(.red)
//        }
//    }
//}
//
//@main
//struct MyApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}

#Preview(body: {
    ContentView()
})
