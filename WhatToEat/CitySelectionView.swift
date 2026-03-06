//
//  CitySelectionView.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/23.
//

import SwiftUI
import CoreLocation

/// 城市选择视图
struct CitySelectionView: View {
    @Binding var selectedCity: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var isAppearing = false
    @StateObject private var locationManager = LocationManager.shared

    private var xhsRed: Color { Color(hex: "#FF2442") }

    private var filteredCities: [String] {
        if searchText.isEmpty {
            return RegionManager.shared.allCities
        }
        return RegionManager.shared.allCities.filter { city in
            city.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            DiffuseGradientBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    headerBar
                    searchCard
                    locationCard
                    cityGridSection
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: filteredCities.count)
        .onAppear {
            locationManager.requestLocationPermission()
            locationManager.getCurrentCity { _ in }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                isAppearing = true
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "#2D3436"))
            }

            Spacer()

            Text("选择城市")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#2D3436"))

            Spacer()

            Button {
                searchText = ""
            } label: {
                Text(searchText.isEmpty ? "完成" : "清空")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#636E72"))
            }
            .opacity(0.95)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: "#FFFFFF").opacity(0.78))
                .shadow(color: Color.black.opacity(0.025), radius: 6, x: 0, y: 2)
        )
        .offset(y: isAppearing ? 0 : -10)
        .opacity(isAppearing ? 1 : 0)
    }

    private var searchCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "#95A0A7"))

            TextField("搜索城市", text: $searchText)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: "#2D3436"))
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#AAB2B9"))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "#FFFFFF").opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "#E7EBEF"), lineWidth: 0.8)
        )
        .offset(y: isAppearing ? 0 : -8)
        .opacity(isAppearing ? 1 : 0)
    }

    private var locationCard: some View {
        Button {
            if let city = locationManager.currentCity {
                selectedCity = city
                dismiss()
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(locationManager.currentCity != nil ? xhsRed : Color(hex: "#AAB2B9"))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(
                                locationManager.currentCity != nil
                                    ? xhsRed.opacity(0.12)
                                    : Color(hex: "#DADFE4")
                            )
                    )

                locationTitleView
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#FFFFFF").opacity(0.76))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(hex: "#E7EBEF"), lineWidth: 0.8)
                    )
            )
        }
        .frame(maxWidth: 336)
        .buttonStyle(PlainButtonStyle())
        .disabled(locationManager.currentCity == nil)
        .offset(y: isAppearing ? 0 : -6)
        .opacity(isAppearing ? 1 : 0)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var locationTitleView: some View {
        if let city = locationManager.currentCity {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("当前位置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#95A0A7"))
                Text(city)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(xhsRed)
            }
        } else {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("定位中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "#95A0A7"))
            }
        }
    }

    private var cityGridSection: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(searchText.isEmpty ? "所有城市" : "搜索结果")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#95A0A7"))
                Spacer()
                Text("\(filteredCities.count) 个")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "#AAB2B9"))
            }

            if filteredCities.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(hex: "#B2BEC3"))
                    Text("没有匹配的城市")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "#95A0A7"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredCities, id: \.self) { city in
                        cityPill(city: city, isSelected: city == selectedCity)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#FFFFFF").opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(hex: "#E7EBEF"), lineWidth: 0.8)
                )
        )
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 8)
    }

    private func cityPill(city: String, isSelected: Bool) -> some View {
        Button {
            selectedCity = city
            dismiss()
        } label: {
            Text(city)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : Color(hex: "#2D3436"))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? xhsRed : Color(hex: "#F2F4F7"))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CitySelectionView(selectedCity: .constant("上海"))
}
