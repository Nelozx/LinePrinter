//
//  TicketPreview.swift
//  LinePrinter
//
//  Created by Antigravity on 2026/9/7.
//

#if canImport(UIKit)
import UIKit
import CoreImage

/// 小票纸张规格尺寸定义
public enum ReceiptPaperWidth: Equatable {
    /// 58mm 规格（标准点阵约 384 点，UI 预览基准宽度约 300pt）
    case mm58
    /// 80mm 规格（标准点阵约 576 点，UI 预览基准宽度约 380pt）
    case mm80
    /// 自定义点阵/点数宽度
    case custom(CGFloat)
    
    /// 预览视图对应的点数宽度
    public var points: CGFloat {
        switch self {
        case .mm58: return 300
        case .mm80: return 380
        case .custom(let w): return w
        }
    }
    
    /// 纸张规格标题
    public var title: String {
        switch self {
        case .mm58: return "58mm 纸宽"
        case .mm80: return "80mm 纸宽"
        case .custom(let w): return "自定义 (\(Int(w))pt)"
        }
    }
}

// MARK: - 小票预览视图 (ReceiptPreviewView)

/// 商业级热敏小票真实外观模拟渲染视图
///
/// 具备逼真热敏纸质感：纸张微阴影、撕纸齿轮虚线边缘、多列对齐排版、CoreImage 条码/二维码生成与切纸指示器。
public class ReceiptPreviewView: UIView {
    
    /// 当前渲染的小票模型
    public private(set) var ticket: Ticket
    
    /// 当前小票纸张规格
    public var paperWidth: ReceiptPaperWidth {
        didSet {
            if oldValue != paperWidth {
                rebuildLayout()
            }
        }
    }
    
    // UI 组件
    private let paperCardView = UIView()
    private let contentStackView = UIStackView()
    private let paperShapeLayer = CAShapeLayer()
    private var widthConstraint: NSLayoutConstraint?
    
    /// 初始化小票预览视图
    /// - Parameters:
    ///   - ticket: 需要预览的小票实体
    ///   - paperWidth: 纸张规格（默认 58mm）
    public init(ticket: Ticket, paperWidth: ReceiptPaperWidth = .mm58) {
        self.ticket = ticket
        self.paperWidth = paperWidth
        super.init(frame: .zero)
        setupUI()
        renderContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 更新展示的小票数据
    /// - Parameter ticket: 新的小票模型
    public func updateTicket(_ ticket: Ticket) {
        self.ticket = ticket
        renderContent()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updatePaperShapeAndShadow()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // 纸张卡片容器 (由 CAShapeLayer 绘制真实热敏撕纸微锯齿，投射高保真轮廓阴影)
        paperCardView.backgroundColor = .clear
        if paperShapeLayer.superlayer == nil {
            paperCardView.layer.insertSublayer(paperShapeLayer, at: 0)
        }
        paperCardView.layer.shadowColor = UIColor.black.cgColor
        paperCardView.layer.shadowOpacity = 0.14
        paperCardView.layer.shadowRadius = 10
        paperCardView.layer.shadowOffset = CGSize(width: 0, height: 5)
        paperCardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(paperCardView)
        
        // 垂直堆叠布局
        contentStackView.axis = .vertical
        contentStackView.spacing = 4
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        paperCardView.addSubview(contentStackView)
        
        let widthAnchorConst = paperCardView.widthAnchor.constraint(equalToConstant: paperWidth.points)
        self.widthConstraint = widthAnchorConst
        
        NSLayoutConstraint.activate([
            paperCardView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            paperCardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            paperCardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            paperCardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            widthAnchorConst,
            
            contentStackView.topAnchor.constraint(equalTo: paperCardView.topAnchor, constant: 18),
            contentStackView.bottomAnchor.constraint(equalTo: paperCardView.bottomAnchor, constant: -20),
            contentStackView.leadingAnchor.constraint(equalTo: paperCardView.leadingAnchor, constant: 14),
            contentStackView.trailingAnchor.constraint(equalTo: paperCardView.trailingAnchor, constant: -14)
        ])
    }
    
    /// 根据当前卡片几何尺寸绘制热敏小票专属撕纸锯齿（Serrated Edge）与阴影
    internal func updatePaperShapeAndShadow() {
        let bounds = paperCardView.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let toothWidth: CGFloat = 6.0
        let toothHeight: CGFloat = 3.5
        let path = UIBezierPath()
        
        // 顶部整齐微倒角切口
        path.move(to: CGPoint(x: 2, y: 0))
        path.addLine(to: CGPoint(x: bounds.width - 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: bounds.width, y: 2), controlPoint: CGPoint(x: bounds.width, y: 0))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - toothHeight))
        
        // 底部真实物理撕纸微锯齿齿痕 (从右至左细密绘制)
        var curX = bounds.width
        while curX > 0 {
            let midX = max(0, curX - toothWidth / 2.0)
            let nextX = max(0, curX - toothWidth)
            path.addLine(to: CGPoint(x: midX, y: bounds.height))
            path.addLine(to: CGPoint(x: nextX, y: bounds.height - toothHeight))
            curX = nextX
        }
        
        path.addLine(to: CGPoint(x: 0, y: 2))
        path.addQuadCurve(to: CGPoint(x: 2, y: 0), controlPoint: CGPoint(x: 0, y: 0))
        path.close()
        
        // 纸张底色：微暖纯净热敏白
        paperShapeLayer.path = path.cgPath
        paperShapeLayer.fillColor = UIColor(red: 0.99, green: 0.99, blue: 0.995, alpha: 1.0).cgColor
        
        // 阴影完全贴合锯齿轮廓
        paperCardView.layer.shadowPath = path.cgPath
    }
    
    private func rebuildLayout() {
        widthConstraint?.constant = paperWidth.points
        layoutIfNeeded()
        updatePaperShapeAndShadow()
    }
    
    // MARK: - 渲染排版
    private func renderContent() {
        contentStackView.arrangedSubviews.forEach {
            contentStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        
        // 顶部进纸装饰
        let topPadding = UIView()
        topPadding.translatesAutoresizingMaskIntoConstraints = false
        topPadding.heightAnchor.constraint(equalToConstant: 2).isActive = true
        contentStackView.addArrangedSubview(topPadding)
        
        // 递归渲染所有排版块
        var hasCutIndicator = false
        renderChunks(ticket.chunks, into: contentStackView, hasCutIndicator: &hasCutIndicator)
        
        // 尾部切纸展示
        if ticket.autoCut && !hasCutIndicator {
            let cutView = makeCutIndicatorView()
            contentStackView.addArrangedSubview(cutView)
        }
    }
    
    private func renderChunks(_ chunks: [Chunk], into stack: UIStackView, hasCutIndicator: inout Bool) {
        for chunk in chunks {
            let provider = chunk.provider
            
            if let group = provider as? ChunkGroup {
                renderChunks(group.elements, into: stack, hasCutIndicator: &hasCutIndicator)
                continue
            }
            
            if let text = provider as? Text {
                let label = makeLabel(from: text)
                stack.addArrangedSubview(label)
            } else if let row = provider as? Row {
                let lineView = makeMultiColumnView(from: row)
                stack.addArrangedSubview(lineView)
            } else if let splitter = provider as? Splitter {
                let splitterView = makeSplitterView(from: splitter)
                stack.addArrangedSubview(splitterView)
            } else if let qr = provider as? QRCode {
                let qrView = makeQRCodeView(from: qr.content)
                stack.addArrangedSubview(qrView)
            } else if let bar = provider as? BarCode {
                let barView = makeBarCodeView(from: bar)
                stack.addArrangedSubview(barView)
            } else if let img = provider as? Image {
                if let cg = img.cgImage {
                    let imgView = makeImageView(from: UIImage(cgImage: cg))
                    stack.addArrangedSubview(imgView)
                }
            } else if let data = provider as? Data {
                // 检查切纸指令 (0x1D, 0x56 即 GS V)
                if data.contains(0x56) && data.contains(0x1D) {
                    hasCutIndicator = true
                    stack.addArrangedSubview(makeCutIndicatorView())
                }
            } else if provider is Blank {
                let blank = UIView()
                blank.translatesAutoresizingMaskIntoConstraints = false
                blank.heightAnchor.constraint(equalToConstant: 12).isActive = true
                stack.addArrangedSubview(blank)
            }
            
            // 垂直进纸点数微调
            if chunk.feedPoints > 0 && chunk.feedPoints != Chunk.defaultFeedPoints {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                let extraHeight = CGFloat(chunk.feedPoints) / 10.0
                spacer.heightAnchor.constraint(equalToConstant: extraHeight).isActive = true
                stack.addArrangedSubview(spacer)
            }
        }
    }
    
    // MARK: - 元素渲染生成器
    private func makeLabel(from text: Text) -> UILabel {
        let label = UILabel()
        label.text = text.content
        label.numberOfLines = 0
        label.textColor = UIColor(white: 0.12, alpha: 1.0)
        
        var isBold = false
        var isDoubleSize = false
        var isDoubleWidth = false
        var isDoubleHeight = false
        var alignment: NSTextAlignment = .left
        
        if let attrs = text.attributes {
            for attr in attrs {
                if let tAttr = attr as? TextAttribute {
                    switch tAttr {
                    case .bold:
                        isBold = true
                    case .doubleSize:
                        isDoubleSize = true
                    case .doubleWidth:
                        isDoubleWidth = true
                    case .doubleHeight:
                        isDoubleHeight = true
                    case .alignment(let cmdAlign):
                        switch cmdAlign {
                        case .left: alignment = .left
                        case .center: alignment = .center
                        case .right: alignment = .right
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        let fontSize: CGFloat = isDoubleSize ? 20.0 : (isDoubleWidth || isDoubleHeight ? 16.0 : 13.0)
        let weight: UIFont.Weight = (isBold || isDoubleSize) ? .bold : .regular
        label.font = ReceiptPreviewView.monospacedFont(ofSize: fontSize, weight: weight)
        label.textAlignment = alignment
        return label
    }
    
    private func makeMultiColumnView(from row: Row) -> UIView {
        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.spacing = 6
        rowStack.distribution = .fill
        rowStack.alignment = .top
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        
        for col in row.columns {
            let label = UILabel()
            label.text = col.text
            label.textColor = UIColor(white: 0.15, alpha: 1.0)
            label.font = ReceiptPreviewView.monospacedFont(ofSize: 12.5, weight: .regular)
            label.numberOfLines = col.isWrapEnabled ? 0 : 1
            
            switch col.alignment {
            case .left: label.textAlignment = .left
            case .center: label.textAlignment = .center
            case .right: label.textAlignment = .right
            }
            
            // 权重与布局约束
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            
            rowStack.addArrangedSubview(label)
            
            // 设置权重比例
            if row.columns.count > 1 {
                label.tag = col.weight
            }
        }
        
        // 动态配置等比例宽度
        let totalWeight = CGFloat(row.columns.reduce(0) { $0 + $1.weight })
        if totalWeight > 0 {
            for (idx, subview) in rowStack.arrangedSubviews.enumerated() {
                let colWeight = CGFloat(row.columns[idx].weight)
                let multiplier = colWeight / totalWeight
                // 约束各列宽度
                let widthConstraint = subview.widthAnchor.constraint(equalTo: rowStack.widthAnchor, multiplier: multiplier, constant: -6)
                widthConstraint.priority = .defaultHigh
                widthConstraint.isActive = true
            }
        }
        
        return rowStack
    }
    
    private func makeSplitterView(from splitter: Splitter) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 12).isActive = true
        
        let line = UIView()
        line.backgroundColor = UIColor(white: 0.82, alpha: 1.0)
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)
        
        NSLayoutConstraint.activate([
            line.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1.0)
        ])
        return container
    }
    
    private func makeQRCodeView(from content: String) -> UIView {
        let container = UIView()
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        
        let size: CGFloat = 120
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            imageView.widthAnchor.constraint(equalToConstant: size),
            imageView.heightAnchor.constraint(equalToConstant: size)
        ])
        
        DispatchQueue.global(qos: .userInitiated).async {
            let qrImg = ReceiptPreviewView.generateQRCode(from: content, targetSize: CGSize(width: size, height: size))
            DispatchQueue.main.async {
                imageView.image = qrImg
            }
        }
        return container
    }
    
    private func makeBarCodeView(from barcode: BarCode) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 3
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let targetHeight: CGFloat = CGFloat(barcode.height > 0 ? barcode.height : 50)
        
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: targetHeight),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: paperWidth.points - 30)
        ])
        
        let codeLabel = UILabel()
        codeLabel.text = barcode.code
        codeLabel.font = ReceiptPreviewView.monospacedFont(ofSize: 11, weight: .regular)
        codeLabel.textColor = UIColor(white: 0.25, alpha: 1.0)
        codeLabel.textAlignment = .center
        
        if barcode.hri == .above || barcode.hri == .both {
            container.addArrangedSubview(codeLabel)
        }
        
        container.addArrangedSubview(imageView)
        
        if barcode.hri == .below || barcode.hri == .both {
            let bottomLabel = UILabel()
            bottomLabel.text = barcode.code
            bottomLabel.font = ReceiptPreviewView.monospacedFont(ofSize: 11, weight: .regular)
            bottomLabel.textColor = UIColor(white: 0.25, alpha: 1.0)
            bottomLabel.textAlignment = .center
            container.addArrangedSubview(bottomLabel)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let barImg = ReceiptPreviewView.generateBarCode(from: barcode.code)
            DispatchQueue.main.async {
                imageView.image = barImg
            }
        }
        return container
    }
    
    private func makeImageView(from image: UIImage) -> UIView {
        let container = UIView()
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        
        let maxHeight: CGFloat = 85
        let maxWidth = paperWidth.points - 32
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: maxHeight),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth)
        ])
        return container
    }
    
    private func makeCutIndicatorView() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        let cutLabel = UILabel()
        cutLabel.text = "✂ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - ✂"
        cutLabel.textColor = UIColor(white: 0.65, alpha: 1.0)
        cutLabel.font = ReceiptPreviewView.monospacedFont(ofSize: 10, weight: .regular)
        cutLabel.textAlignment = .center
        cutLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cutLabel)
        
        NSLayoutConstraint.activate([
            cutLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            cutLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            cutLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }
    
    // MARK: - 静态工具函数
    public static func monospacedFont(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if #available(iOS 13.0, *) {
            return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        } else {
            return UIFont(name: "Menlo", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
    
    public static func generateQRCode(from text: String, targetSize: CGSize) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        let data = text.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let output = filter.outputImage else { return nil }
        let scaleX = targetSize.width / output.extent.size.width
        let scaleY = targetSize.height / output.extent.size.height
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let context = CIContext()
        if let cgImage = context.createCGImage(transformed, from: transformed.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    public static func generateBarCode(from text: String) -> UIImage? {
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
        let data = text.data(using: .ascii) ?? text.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(7.0, forKey: "inputQuietSpace")
        
        guard let output = filter.outputImage else { return nil }
        let scaleTransform = CGAffineTransform(scaleX: 2.2, y: 2.0)
        let transformed = output.transformed(by: scaleTransform)
        let context = CIContext()
        if let cgImage = context.createCGImage(transformed, from: transformed.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}

// MARK: - Ticket 预览模式便捷扩展

public extension Ticket {
    
    /// 创建并获取当前小票的 UI 视觉预览视图（`ReceiptPreviewView`）
    /// - Parameter paperWidth: 纸张宽度（默认 58mm）
    /// - Returns: 高保真小票渲染 UIView，调用方可自由放置于任意 UI 容器中进行展示或自行实现动画
    ///
    /// ```swift
    /// let preview = ticket.previewView(paperWidth: .mm58)
    /// myContainerView.addSubview(preview)
    /// ```
    func previewView(paperWidth: ReceiptPaperWidth = .mm58) -> ReceiptPreviewView {
        ReceiptPreviewView(ticket: self, paperWidth: paperWidth)
    }
    
    /// 将小票渲染并导出为一张高清晰度长图 `UIImage`
    /// - Parameters:
    ///   - paperWidth: 纸张宽度（默认 58mm）
    ///   - scale: 图像导出渲染缩放倍率（默认 2.0x 视网膜高清度）
    /// - Returns: 完整渲染长图 UIImage
    ///
    /// ```swift
    /// if let image = ticket.previewImage() {
    ///     // 保存相册或调用分享
    /// }
    /// ```
    func previewImage(paperWidth: ReceiptPaperWidth = .mm58, scale: CGFloat = 2.0) -> UIImage? {
        let view = ReceiptPreviewView(ticket: self, paperWidth: paperWidth)
        let targetWidth = paperWidth.points
        
        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let size = CGSize(width: targetWidth + 24, height: max(fittingSize.height + 24, 100))
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            view.layer.render(in: ctx.cgContext)
        }
    }
}
#endif
