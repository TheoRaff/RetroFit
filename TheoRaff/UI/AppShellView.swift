//
//  AppShellView.swift
//  TheoRaff
//
//  Created by Theo Rook on 24/10/2026.
//

import SwiftUI
import UIKit

struct AppShellView: View {
    let session: TryOnSession

    @State private var selectedTab = AppTab.tryOn

    private var catalogGarments: [Garment] {
        Catalog.bundled.garments
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView(session: session)
                .tabItem {
                    Label("Try On", systemImage: "camera")
                }
                .tag(AppTab.tryOn)

            ClosetView(garments: catalogGarments, session: session)
                .tabItem {
                    Label("Closet", systemImage: "hanger")
                }
                .tag(AppTab.closet)

            ProfileView(session: session)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(AppTab.profile)
        }
    }
}

private enum AppTab {
    case tryOn
    case closet
    case profile
}

private struct ClosetView: View {
    let garments: [Garment]
    let session: TryOnSession

    @State private var searchText = ""
    @State private var selectedCategory = ClosetCategory.all
    @State private var tryOnPrompt: Garment?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var filteredGarments: [Garment] {
        garments.filter { garment in
            let matchesCategory: Bool

            switch selectedCategory {
            case .all:
                matchesCategory = true
            case .tops:
                matchesCategory = garment.category == .top
            case .bottoms:
                matchesCategory = garment.category == .bottom
            case .head:
                matchesCategory = garment.category == .headwear
                    || garment.category == .eyewear
            }

            let searchableText = (
                [garment.name, garment.searchQuery] + garment.tags
            )
            .joined(separator: " ")

            let matchesSearch = searchText.isEmpty
                || searchableText.localizedCaseInsensitiveContains(searchText)

            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextField("Search closet", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $selectedCategory) {
                    ForEach(ClosetCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)

                if filteredGarments.isEmpty {
                    ContentUnavailableView(
                        "No clothes found",
                        systemImage: "tshirt",
                        description: Text("Try another search or category.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredGarments) { garment in
                                GarmentCard(garment: garment, session: session)
                                    .contentShape(Rectangle())
                                    .onTapGesture { tryOnPrompt = garment }
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            .padding()
            .background(Color(red: 0.70, green: 0.69, blue: 0.67))
            .navigationTitle("Closet")
            .aiTryOnPrompt(for: $tryOnPrompt)
        }
    }
}

private enum ClosetCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case tops = "Tops"
    case bottoms = "Bottoms"
    case head = "Head"

    var id: Self { self }
}

private struct GarmentCard: View {
    let garment: Garment
    let session: TryOnSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)

                if let image = UIImage(named: garment.imageName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else {
                    Image(systemName: placeholderSymbol)
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 145)

            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(garment.name)
                        .font(.headline)
                        .lineLimit(2)

                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                FindItMenu(garment: garment) {
                    Image(systemName: "bag")
                }
                .tint(.primary)

                Button {
                    if session.isLiked(garment) {
                        session.unlike(garment)
                    } else {
                        session.like(garment)
                    }
                } label: {
                    Image(systemName: session.isLiked(garment) ? "heart.fill" : "heart")
                        .foregroundStyle(session.isLiked(garment) ? .pink : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    session.isLiked(garment) ? "Remove from saved items" : "Save item"
                )
            }
        }
        .padding(10)
        .background(
            Color(red: 0.78, green: 0.77, blue: 0.75),
            in: RoundedRectangle(cornerRadius: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.8), lineWidth: 1)
        )
    }

    private var categoryName: String {
        switch garment.category {
        case .eyewear: "Head"
        case .headwear: "Head"
        case .top: "Top"
        case .bottom: "Bottom"
        case .fullLook: "Look"
        }
    }

    private var placeholderSymbol: String {
        switch garment.category {
        case .eyewear: "eyeglasses"
        case .headwear: "person.crop.circle"
        case .top: "tshirt"
        case .bottom: "figure.walk"
        case .fullLook: "sparkles"
        }
    }
}

private struct ProfileView: View {
    let session: TryOnSession

    var body: some View {
        NavigationStack {
            List {
                Section("Your style") {
                    LabeledContent(
                        "Liked garments",
                        value: "\(session.closet.count)"
                    )
                }
            }
            .navigationTitle("Profile")
        }
    }
}
