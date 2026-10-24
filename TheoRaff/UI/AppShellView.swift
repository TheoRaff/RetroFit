//
//  AppShellView.swift
//  TheoRaff
//
//  Created by Theo Rook on 24/10/2026.
//

import SwiftUI

struct AppShellView: View {
    let session: TryOnSession

    @State private var selectedTab = AppTab.closet
    /// Set by Try On and the closet; the dialogs live here so they cover the tab bar too.
    @State private var tryOnPrompt: AITryOnLook?
    @State private var findIt: Garment?

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView(session: session, tryOnPrompt: $tryOnPrompt)
                .tag(AppTab.tryOn)

            ClosetView(garments: Catalog.bundled.garments, session: session, tryOnPrompt: $tryOnPrompt, findIt: $findIt)
                .tag(AppTab.closet)

            ProfileView(session: session)
                .tag(AppTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
        .aiTryOnPrompt(for: $tryOnPrompt, session: session)
        .findItPrompt(for: $findIt)
        .task { await ProductPhoto.preload(photoNames) }
        // The Windows look is a fixed light theme. Dark only on Try On, so the status bar
        // shows white over the camera, as in the mockup.
        .preferredColorScheme(selectedTab == .tryOn ? .dark : .light)
    }

    /// Every garment photo, the first look's first so the Try On card fills in straight away.
    private var photoNames: [String] {
        let deck = session.outfits.flatMap(\.garments).map(\.imageName)
        return deck + Catalog.bundled.garments.map(\.imageName)
    }

    /// The grey taskbar-style tab strip: the selected tab is pressed in, with the dither fill.
    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(.tryOn, title: "Try On", symbol: "camera")
            tabButton(.closet, title: "Closet", symbol: "hanger")
            tabButton(.profile, title: "Profile", symbol: "person")
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        // The same height as the hidden system tab bar, which the pages still leave room for.
        // The pressed tab hangs a little into the home indicator area, as in the mockup.
        .frame(height: 49, alignment: .top)
        .background(Win95.face.ignoresSafeArea(edges: .bottom))
        // An etched line along the top edge.
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                Win95.shadow.frame(height: 1)
                Win95.highlight.frame(height: 1)
            }
        }
    }

    private func tabButton(_ tab: AppTab, title: String, symbol: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .regular))
                Text(title)
                    .font(Win95.font(11, bold: isSelected, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Win95.navy : Win95.text)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if isSelected {
                    Win95Dither()
                }
            }
            .overlay {
                if isSelected {
                    Win95Bevel(style: .sunken)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum AppTab {
    case tryOn
    case closet
    case profile
}
