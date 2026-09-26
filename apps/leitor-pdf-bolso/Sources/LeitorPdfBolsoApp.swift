import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import UIKit

@main
struct LeitorPdfBolsoApp: App {
    var body: some Scene { WindowGroup { PDFLibraryView() } }
}

struct PDFProgress: Codable, Equatable {
    var page: Int
    var pageCount: Int

    var safePage: Int { min(max(page, 0), max(pageCount - 1, 0)) }
}

struct PDFLibraryEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let pageCount: Int
}

struct PDFLibraryView: View {
    @State private var documents: [PDFLibraryEntry] = []
    @State private var showImporter = false
    @State private var importError: String?
    @State private var search = ""
    private let accent = Color(red: 0.14, green: 0.35, blue: 0.54)
    private var capture: String? { FactoryCapture.screen }

    var body: some View {
        NavigationStack {
            Group {
                if capture == "reader", let first = documents.first {
                    PDFReaderScreen(entry: first)
                } else { library }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true, onCompletion: importFiles)
            .onAppear {
                if FactoryCapture.isUITesting { FactoryCapture.resetAppDefaults() }
                refreshLibrary()
            }
        }
        .tint(accent)
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 20) {
            FactoryHeader(eyebrow: "Leitura no seu ritmo", title: "Sua biblioteca.", subtitle: "Abra documentos pelo app Arquivos e continue de onde parou, sem enviar nada para a nuvem.", accent: accent)
            FactoryDemoNotice(message: "Documento de exemplo local · nenhum dado enviado")
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(accent)
                TextField("Buscar pelo nome", text: $search).accessibilityLabel("Buscar PDFs pelo nome")
            }.padding(14).background(FactoryColor.card, in: RoundedRectangle(cornerRadius: 15))
            if filteredDocuments.isEmpty {
                FactoryPanel {
                    ContentUnavailableView("Sua biblioteca está vazia", systemImage: "doc.text", description: Text("Importe um PDF pelo app Arquivos para começar."))
                    Button { showImporter = true } label: { Label("Importar PDF", systemImage: "plus") }
                        .buttonStyle(FactoryPrimaryButtonStyle())
                }
            } else {
                ForEach(filteredDocuments) { entry in
                    NavigationLink(value: entry) {
                        FactoryPanel {
                            HStack(spacing: 15) {
                                RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.12)).frame(width: 52, height: 62)
                                    .overlay(Image(systemName: "doc.text.fill").font(.title2).foregroundStyle(accent))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.name).font(.headline).foregroundStyle(.primary).lineLimit(2)
                                    Text("\(entry.pageCount) páginas · armazenado neste aparelho")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(entry.name)
                    .accessibilityIdentifier("pdf-document-\(entry.name)")
                }
                Button { showImporter = true } label: { Label("Importar outro PDF", systemImage: "plus") }
                    .buttonStyle(FactoryPrimaryButtonStyle())
            }
            if let importError { Text(importError).font(.footnote).foregroundStyle(.red) }
            FactoryPanel(title: "Privacidade", systemImage: "lock.shield.fill") {
                Text("Os documentos ficam no dispositivo. PDF protegido solicita senha apenas para a sessão; PDFs de imagem não têm busca de texto nesta versão.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .factoryPage(backgroundColor: Color(red: 0.97, green: 0.97, blue: 0.94)).navigationTitle("Leitor PDF").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PDFLibraryEntry.self) { PDFReaderScreen(entry: $0) }
    }

    private var filteredDocuments: [PDFLibraryEntry] {
        search.isEmpty ? documents : documents.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private func refreshLibrary() {
        let directory = Self.libraryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if documents.isEmpty { Self.createDemoPDF(in: directory) }
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        documents = urls.compactMap { url -> PDFLibraryEntry? in
            guard url.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: url) else { return nil }
            let fileName = url.deletingPathExtension().lastPathComponent
            let displayName = fileName == "Guia-de-leitura-demonstrativo" ? "Guia de leitura demonstrativo" : fileName
            return PDFLibraryEntry(id: url.path, name: displayName, url: url, pageCount: pdf.pageCount)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            for source in urls {
                let granted = source.startAccessingSecurityScopedResource()
                defer { if granted { source.stopAccessingSecurityScopedResource() } }
                let destination = Self.libraryDirectory.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
                try FileManager.default.copyItem(at: source, to: destination)
            }
            importError = nil
            refreshLibrary()
        } catch {
            importError = "Não foi possível importar esse arquivo. Confira se ele é um PDF válido e tente novamente."
        }
    }

    static var libraryDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ImportedPDFs", isDirectory: true)
    }

    private static func createDemoPDF(in directory: URL) {
        let url = directory.appendingPathComponent("Guia-de-leitura-demonstrativo.pdf")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            let title = "Guia de leitura demonstrativo"
            let body = "Este documento foi criado localmente para testar a biblioteca.\n\nVocê pode pesquisar esta palavra: biblioteca.\n\nO protótipo não envia arquivos para servidores."
            title.draw(at: CGPoint(x: 56, y: 72), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 25), .foregroundColor: UIColor.darkGray])
            body.draw(in: CGRect(x: 56, y: 130, width: 500, height: 360), withAttributes: [.font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.darkGray])
        }
        try? data.write(to: url, options: .atomic)
    }
}

struct PDFReaderScreen: View {
    let entry: PDFLibraryEntry
    @State private var searchText = ""
    @State private var resultCount = 0
    @State private var selection: PDFSelection?
    @State private var bookmarked = false
    @State private var currentPage = 0
    @State private var pdfDocument: PDFDocument?
    private let accent = Color(red: 0.14, green: 0.35, blue: 0.54)

    private var document: PDFDocument? { pdfDocument }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                TextField("Buscar neste documento", text: $searchText)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Buscar no documento")
                Button("Buscar") { searchDocument() }.buttonStyle(.borderedProminent).tint(accent)
            }.padding(12)
            if resultCount > 0 {
                Text("\(resultCount) resultado(s) · ocorrência selecionada")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14)
            } else if !searchText.isEmpty {
                Text("Nenhum resultado de texto. PDFs formados apenas por imagem não são pesquisáveis nesta versão.")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14)
            }
            PDFKitReader(document: document, selection: selection, currentPage: $currentPage)
                .accessibilityIdentifier("pdf-document-view")
            HStack {
                Label("\(document?.pageCount ?? 0) páginas", systemImage: "doc.text")
                Spacer()
                Button {
                    bookmarked.toggle()
                    UserDefaults.standard.set(bookmarked, forKey: "pdf.bookmark.\(entry.id)")
                    UserDefaults.standard.set(currentPage, forKey: "pdf.bookmark.page.\(entry.id)")
                } label: { Label(bookmarked ? "Marcado" : "Marcar página", systemImage: bookmarked ? "bookmark.fill" : "bookmark") }
                    .buttonStyle(.bordered)
            }.font(.caption).padding(12).background(.regularMaterial)
        }
        .navigationTitle(entry.name).navigationBarTitleDisplayMode(.inline)
        .onAppear {
            pdfDocument = PDFDocument(url: entry.url)
            bookmarked = UserDefaults.standard.bool(forKey: "pdf.bookmark.\(entry.id)")
            let saved = UserDefaults.standard.integer(forKey: "pdf.page.\(entry.id)")
            let pageCount = pdfDocument?.pageCount ?? 0
            currentPage = PDFProgress(page: saved, pageCount: pageCount).safePage
            if bookmarked { currentPage = PDFProgress(page: UserDefaults.standard.integer(forKey: "pdf.bookmark.page.\(entry.id)"), pageCount: pageCount).safePage }
        }
        .onChange(of: currentPage) { _, page in UserDefaults.standard.set(page, forKey: "pdf.page.\(entry.id)") }
    }

    private func searchDocument() {
        guard let document, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { resultCount = 0; selection = nil; return }
        let matches = document.findString(searchText, withOptions: [.caseInsensitive])
        resultCount = matches.count
        selection = matches.first
    }
}

struct PDFKitReader: UIViewRepresentable {
    let document: PDFDocument?
    let selection: PDFSelection?
    @Binding var currentPage: Int

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = document
        view.delegate = context.coordinator
        context.coordinator.parent = self
        if let page = view.document?.page(at: currentPage) { view.go(to: page) }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        if let document, view.document !== document { view.document = document }
        if let activeDocument = view.document, let page = activeDocument.page(at: currentPage) {
            let visibleIndex = view.currentPage.map { activeDocument.index(for: $0) }
            if visibleIndex != currentPage { view.go(to: page) }
        }
        if let selection { view.go(to: selection); view.setCurrentSelection(selection, animate: true) }
    }

    final class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitReader
        init(parent: PDFKitReader) { self.parent = parent }

        func pdfViewPageChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView,
                  let page = view.currentPage,
                  let document = view.document else { return }
            parent.currentPage = max(document.index(for: page), 0)
        }
    }
}
