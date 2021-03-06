//
//  NetworkView.swift
//  LuCI
//
//  Created by CGH on 2022/4/4.
//

import Foundation
import SwiftUI
import MapKit

struct NetworkView: View {
    var body: some View {
        NavigationView {
            GeometryReader { metrics in
                List {
                    IPView(width: metrics.size.width)
                }
            }
            .navigationTitle("Network")
        }
        .navigationViewStyle(.stack)
    }
}

struct IPView: View {
    var width: CGFloat

    @AppStorage("currentIpAddress") private var current = IPInfo()
    @State var updating: Bool = false

    func update() {
        Task {
            updating = true
            let resp = try? await IPAddress.IPGeolocation.shared.get()
            if let info = resp?.toIPInfo() {
                current = info
            }
            updating = false
        }
    }

    var data: [[String]] {
        [
            [ "IP Address", current.ipAddress ?? "-" ],
            [ "Location", current.location ?? "-" ],
            [ "Organization", current.orgName ?? "-" ],
            [ "ISP", current.ispName ?? "-" ],
        ]
    }

    var body: some View {
        Section {
            ForEach(data, id: \.self) { line in
                VStack {
                    HStack {
                        Text(line[0])
                            #if os(watchOS)
                            .font(.system(size: 13))
                            #endif
                        Spacer()
                        Text(line[1])
                            .multilineTextAlignment(.trailing)
                            .frame(width: width * 0.4, alignment: .trailing)
                            .foregroundStyle(.secondary)
                            #if os(watchOS)
                            .font(.system(size: 13))
                            .minimumScaleFactor(0.6)
                            .lineLimit(3)
                            #else
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                            #endif
                    }
                }
            }
            Button(action: update, label: {
                HStack {
                    Text("Update")
                        .foregroundColor(updating ? .secondary : .green)
                        #if os(watchOS)
                        .font(.system(size: 13))
                        #endif
                    if updating {
                        Spacer()
                        ProgressView()
                            #if os(watchOS)
                            .frame(width: 20)
                            .scaleEffect(0.5)
                            #endif
                    } else if current.createdAt != nil {
                        Spacer()
                        Text("Last updated at \(current.createdAtString!)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
            }).disabled(updating)
            #if os(iOS)
            if let name = current.ipAddress, let lat = current.latitude, let lng = current.longitude {
                IPMapView(name: name, latitude: lat, longitude: lng, updating: $updating)
                    .listRowInsets(EdgeInsets())
            }
            #endif
        } header: {
            Text("IP Address")
        }.onAppear {
            if current.createdAt == nil || Date().timeIntervalSince(current.createdAt!) > 60 * 60 * 3 {
                update()
            }
        }
    }
}

struct Coord2D: Equatable {
    var coordinates: CLLocationCoordinate2D

    static func == (lhs: Coord2D, rhs: Coord2D) -> Bool {
        return lhs.coordinates.latitude == rhs.coordinates.latitude &&
        lhs.coordinates.longitude == rhs.coordinates.longitude
    }
}

#if os(iOS)
struct IPMapView: View {
    var name: String
    var latitude: String
    var longitude: String

    var coordinates: Coord2D {
        let coords = CLLocationCoordinate2D(latitude: Double(latitude) ?? 0, longitude: Double(longitude) ?? 0)
        return Coord2D(coordinates: coords)
    }

    var span: MKCoordinateSpan {
        let delta = 10.0
        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }

    @Binding var updating: Bool
    @State private var snapshotImage = UIImage()
    @State private var width: CGFloat = 200
    @State private var height: CGFloat = 200

    var imageLoaded: Bool {
        return snapshotImage.size.height > 0
    }

    private func generate(_ coords: CLLocationCoordinate2D) {
        self.updating = true
        let region = MKCoordinateRegion(
            center: coords,
            span: span
        )
        let opts = MKMapSnapshotter.Options()
        opts.region = region
        opts.size = CGSize(width: width, height: height)
        opts.mapType = .satellite
        let snapshotter = MKMapSnapshotter(options: opts)
        snapshotter.start { (snapshot, error) in
            if let snap = snapshot {
                snapshotImage = snap.image
            }
            self.updating = false
        }
    }

    var body: some View {
        GeometryReader { metrics in
            Image(uiImage: snapshotImage)
                .frame(width: width, height: height, alignment: .center)
                .onChange(of: coordinates) { newValue in
                    generate(newValue.coordinates)
                }
                .overlay(alignment: .bottomTrailing) {
                    if updating {
                        ProgressView()
                            .padding(.bottom, 15)
                            .padding(.trailing, 15)
                            .progressViewStyle(imageLoaded ? CircularProgressViewStyle(tint: .white) : .circular)
                    }
                }
                .onTapGesture {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinates.coordinates))
                    item.name = name
                    item.openInMaps(launchOptions: [
                        MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinates.coordinates),
                        MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: span),
                    ])
                }
                .onAppear {
                    self.width = metrics.size.width
                }
        }
        .frame(height: height)
        .onAppear {
            if !imageLoaded {
                generate(coordinates.coordinates)
            }
        }
    }
}
#endif
