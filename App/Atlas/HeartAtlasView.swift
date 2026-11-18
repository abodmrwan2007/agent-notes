import AgentNotesCore
import SceneKit
import SwiftUI
import UIKit

/// The heart model: geometry and part list from the asset catalog, turned into SceneKit nodes.
@MainActor
final class HeartModel {
    let manifest: AnatomyModelManifest
    let scene = SCNScene()
    private(set) var nodes: [String: SCNNode] = [:]

    init?() {
        guard let partsData = Self.dataAsset("heart-parts"),
              let binary = Self.dataAsset("heart-model"),
              let manifest = try? AnatomyModelManifest.decode(partsData),
              manifest.problems(binary: binary).isEmpty else { return nil }
        self.manifest = manifest

        let root = SCNNode()
        scene.rootNode.addChildNode(root)
        for part in manifest.parts {
            let node = SCNNode(geometry: Self.geometry(for: part, binary: binary))
            node.name = part.id
            root.addChildNode(node)
            nodes[part.id] = node
        }

        let camera = SCNCamera()
        camera.fieldOfView = 40
        camera.zNear = 1
        camera.zFar = 200
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 36)
        cameraNode.name = "camera"
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .ambient
        light.light?.intensity = 350
        scene.rootNode.addChildNode(light)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 900
        key.eulerAngles = SCNVector3(-0.6, 0.4, 0)
        scene.rootNode.addChildNode(key)
    }

    private static func geometry(for part: AnatomyPart, binary: Data) -> SCNGeometry {
        let vertexBytes = binary.subdata(in: part.vertexOffset..<(part.vertexOffset + part.vertexCount * AnatomyPart.bytesPerVertex))
        let indexBytes = binary.subdata(in: part.indexOffset..<(part.indexOffset + part.indexCount * AnatomyPart.bytesPerIndex))
        let positions = SCNGeometrySource(
            data: vertexBytes, semantic: .vertex, vectorCount: part.vertexCount,
            usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4,
            dataOffset: 0, dataStride: AnatomyPart.bytesPerVertex)
        let normals = SCNGeometrySource(
            data: vertexBytes, semantic: .normal, vectorCount: part.vertexCount,
            usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4,
            dataOffset: 12, dataStride: AnatomyPart.bytesPerVertex)
        let element = SCNGeometryElement(
            data: indexBytes, primitiveType: .triangles,
            primitiveCount: part.indexCount / 3, bytesPerIndex: AnatomyPart.bytesPerIndex)
        let geometry = SCNGeometry(sources: [positions, normals], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(hex: part.color)
        material.lightingModel = .blinn
        material.specular.contents = UIColor(white: 0.25, alpha: 1)
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }

    private static func dataAsset(_ name: String) -> Data? {
        if let asset = NSDataAsset(name: name, bundle: .main) { return asset.data }
        #if SWIFT_PACKAGE
        return NSDataAsset(name: name, bundle: .module)?.data
        #else
        return nil
        #endif
    }

    /// Shows the chosen parts, makes the chambers see-through by `chamberOpacity` and lights up
    /// the selected part.
    func apply(hidden: Set<String>, selected: String?, chamberOpacity: Double) {
        for part in manifest.parts {
            guard let node = nodes[part.id] else { continue }
            node.isHidden = hidden.contains(part.id)
            // Only the walls become see-through, so the cavities and valves inside show.
            let isWall = part.sources.contains { $0.lowercased().hasPrefix("wall of") }
            node.opacity = isWall ? CGFloat(chamberOpacity) : 1
            let material = node.geometry?.firstMaterial
            material?.emission.contents = part.id == selected
                ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
                : UIColor.black
        }
    }

    func resetCamera(in view: SCNView) {
        view.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: false)
    }
}

/// Keeps the whole model in frame: the field of view applies to the narrower side of the view,
/// so a tall, narrow view (iPad portrait with the sidebar) does not crop the heart.
private final class FittingSceneView: SCNView {
    override func layoutSubviews() {
        super.layoutSubviews()
        pointOfView?.camera?.projectionDirection = bounds.width < bounds.height ? .horizontal : .vertical
    }
}

/// SceneKit view with built-in rotate (one finger), zoom (pinch) and move (two fingers).
private struct HeartSceneView: UIViewRepresentable {
    let model: HeartModel
    @Binding var selected: String?
    let resetToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(selected: $selected) }

    func makeUIView(context: Context) -> SCNView {
        let view = FittingSceneView()
        view.scene = model.scene
        view.allowsCameraControl = true
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        model.resetCamera(in: view)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        view.addGestureRecognizer(tap)
        view.accessibilityIdentifier = "atlas.scene"
        context.coordinator.lastReset = resetToken
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.selected = $selected
        if context.coordinator.lastReset != resetToken {
            context.coordinator.lastReset = resetToken
            model.resetCamera(in: view)
        }
    }

    final class Coordinator: NSObject {
        var selected: Binding<String?>
        var lastReset = 0

        init(selected: Binding<String?>) { self.selected = selected }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let hits = view.hitTest(gesture.location(in: view), options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .ignoreHiddenNodes: true
            ])
            selected.wrappedValue = hits.first?.node.name
        }
    }
}

/// Atlas ▸ Heart: a 3D heart from BodyParts3D that can be turned, zoomed and taken apart.
struct HeartAtlasView: View {
    @State private var model: HeartModel?
    @State private var loadFailed = false
    @State private var selected: String?
    @State private var hidden: Set<String> = []
    @State private var chamberOpacity = 1.0
    @State private var resetToken = 0

    private var arabic: Bool { Bundle.main.preferredLocalizations.first?.hasPrefix("ar") == true }

    var body: some View {
        Group {
            if let model {
                HStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        HeartSceneView(model: model, selected: $selected, resetToken: resetToken)
                        selectionCard(model: model)
                            .padding(12)
                    }
                    Divider()
                    partList(model: model)
                        .frame(width: 320)
                }
                .onAppear { model.apply(hidden: hidden, selected: selected, chamberOpacity: chamberOpacity) }
                .onChange(of: selected) { _, _ in model.apply(hidden: hidden, selected: selected, chamberOpacity: chamberOpacity) }
                .onChange(of: hidden) { _, _ in model.apply(hidden: hidden, selected: selected, chamberOpacity: chamberOpacity) }
                .onChange(of: chamberOpacity) { _, _ in model.apply(hidden: hidden, selected: selected, chamberOpacity: chamberOpacity) }
            } else if loadFailed {
                ContentUnavailableView("The heart model could not be loaded", systemImage: "exclamationmark.triangle")
            } else {
                ProgressView("Loading the heart model…")
            }
        }
        .task {
            guard model == nil, !loadFailed else { return }
            model = HeartModel()
            loadFailed = model == nil
        }
        .navigationTitle("Heart")
        .background(Theme.backdrop)
    }

    @ViewBuilder
    private func selectionCard(model: HeartModel) -> some View {
        if let id = selected, let part = model.manifest.parts.first(where: { $0.id == id }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: part.name(arabic: arabic))
                        .font(.headline)
                        .accessibilityIdentifier("atlas.selected")
                    Text(verbatim: part.name(arabic: !arabic))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Show only this") {
                    hidden = Set(model.manifest.parts.map(\.id)).subtracting([id])
                }
                .accessibilityIdentifier("atlas.isolate")
                Button("Hide") {
                    hidden.insert(id)
                    selected = nil
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        } else {
            Text("Drag to turn, pinch to zoom, tap a part to name it.")
                .font(.callout)
                .padding(10)
                .background(.regularMaterial, in: Capsule())
        }
    }

    private func partList(model: HeartModel) -> some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text("See-through walls")
                    Slider(value: $chamberOpacity, in: 0.15...1)
                        .accessibilityIdentifier("atlas.opacity")
                }
                HStack {
                    Button("Show all") {
                        hidden = []
                        chamberOpacity = 1
                    }
                    .accessibilityIdentifier("atlas.showAll")
                    Spacer()
                    Button("Reset view") { resetToken += 1 }
                }
                .buttonStyle(.borderless)
            }
            ForEach(AnatomyPart.Group.allCases, id: \.self) { group in
                Section(header: Text(title(of: group))) {
                    ForEach(model.manifest.parts.filter { $0.group == group }) { part in
                        HStack {
                            Button {
                                selected = part.id
                            } label: {
                                HStack {
                                    Circle().fill(Color(UIColor(hex: part.color))).frame(width: 12, height: 12)
                                    Text(verbatim: part.name(arabic: arabic))
                                        .foregroundStyle(selected == part.id ? Theme.accent : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("atlas.part.\(part.id)")
                            Spacer()
                            Toggle("Show", isOn: Binding(
                                get: { !hidden.contains(part.id) },
                                set: { if $0 { hidden.remove(part.id) } else { hidden.insert(part.id) } }))
                                .labelsHidden()
                                .accessibilityIdentifier("atlas.toggle.\(part.id)")
                        }
                    }
                }
            }
            Section {
                Text("3D data: BodyParts3D, © The Database Center for Life Science, licensed under CC Attribution-Share Alike 2.1 Japan. Reduced and coloured for this app. A study model, not reviewed by an anatomist. The muscle wall of both ventricles is one piece.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func title(of group: AnatomyPart.Group) -> LocalizedStringKey {
        switch group {
        case .chambers: return "Chambers"
        case .valves: return "Valves and papillary muscles"
        case .vessels: return "Great vessels"
        case .coronary: return "Coronary vessels"
        }
    }
}
