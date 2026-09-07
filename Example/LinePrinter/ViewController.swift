//
//  ViewController.swift
//  LinePrinter
//
//  Created by Nelo on 04/12/2022.
//  Copyright (c) 2022 Nelo. All rights reserved.
//

import UIKit
import LinePrinter
import Network
import AudioToolbox

class MockTransport: PrinterTransport {
    func write(_ data: Data) {
        print("模拟底层写通道收到数据：\(data.count) bytes，当前线程：\(Thread.current)")
        // 模拟硬件打印耗时，确保下一张小票会被队列阻塞等待
        Thread.sleep(forTimeInterval: 1.0)
    }
}

class ViewController: UIViewController {

    @IBOutlet weak var top: UIImageView?
    @IBOutlet weak var bottom: UIImageView?

    // 视图容器
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let segmentWidth = UISegmentedControl(items: ["58mm (硬编码)", "80mm (硬编码)", "JSON 云端排版"])
    
    // 模拟打印机出纸口槽位
    private let printerSlotView = UIView()
    private var slotWidthConstraint: NSLayoutConstraint?
    private var isPrinting: Bool = false
    private var printingTimer: Timer?
    
    // 空闲待机状态卡片（在尚未开始出纸时展示，防止小票内容提前暴露）
    private let idlePlaceholderView = UIView()
    
    // 原生小票预览组件 (ReceiptPreviewView)
    private var receiptPreviewView: ReceiptPreviewView?
    private var previewWidthConstraint: NSLayoutConstraint?
    
    // 当前构建的小票与指令流
    private var currentTicket: Ticket?
    private var currentPrintData: Data = Data()
    private var currentPaperWidth: Int = 32
    
    // 由外部调用者（App）自行维护的打印队列演示
    private let demoPrintQueue = DispatchQueue(label: "com.example.printQueue", qos: .userInitiated)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadReceipt(width: 32, playAnimation: false)
    }

    // MARK: - 构建小票模型
    private func buildTicket(totalWidth: Int) -> Ticket {
        let logoImage = UIImage(named: "good") ?? makeDemoLogoImage()
        let printDensity = totalWidth == 32 ? 384 : 576
        
        return LinePrinter.ticket(
            // 1. 顶部行间距与蜂鸣器设置
            .spacing(22),
            // 2. 顶部 Logo 图案 (单色位图抖动打印)
            .image(logoImage, dither: .floydSteinberg),
            // 3. 店铺名与单号时间
            .text("味美餐饮旗舰店", bold: true, alignment: .center),
            .text("-- 欢迎光临 --", attributes: [TextAttribute.alignment(.center)]),
            .splitter("-", printDensity: printDensity),
            .text("单号：NO.20260907001"),
            .text("时间：2026-09-07 12:30:00"),
            .text("收银员：01号"),
            .splitter("-", printDensity: printDensity),
            // 3. 三列明细表头
            .row(totalWidth: totalWidth,
                 Line("品名", weight: 2, alignment: .left),
                 Line("数量", weight: 1, alignment: .center),
                 Line("金额", weight: 1, alignment: .right)),
            .splitter("-", printDensity: printDensity),
            // 5. 菜品列表（直接使用统一的 .row，开启智能折行 wrap: true）
            .row("招牌老坛酸菜无骨黑鱼饭(大份)", "x1", "38.00", totalWidth: totalWidth, wrap: true),
            .row("秘制香辣鸭头", "x2", "16.00", totalWidth: totalWidth, wrap: true),
            .row("冰镇大麦若叶汁", "x1", "8.00", totalWidth: totalWidth, wrap: true),
            .splitter("-", printDensity: printDensity),
            // 6. 账单汇总（直接使用统一的 .row）
            .row("原价合计", "￥62.00", totalWidth: totalWidth),
            .row("会员优惠券", "-￥12.00", totalWidth: totalWidth),
            .row("实付金额", "￥50.00", totalWidth: totalWidth),
            .splitter("=", printDensity: printDensity),
            // 7. 支付信息与加粗取餐号
            .text("支付方式：微信支付"),
            .text("【取餐号：A088】", bold: true, alignment: .center),
            .splitter("-", printDensity: printDensity),
            // 8. 电子发票二维码与一维条码（带下方 HRI 数字）
            .text("扫码开具增值税电子发票", attributes: [TextAttribute.alignment(.center)]),
            .qrcode("https://weixin.qq.com/r/lineprinter_demo"),
            .barcode("20260907001", type: .code128, height: 60, width: 2, hri: .below),
            // 9. 结尾问候与出单提示
            .text("多谢惠顾，欢迎再次光临！", attributes: [TextAttribute.alignment(.center)]),
            .defaultSpacing,
            .beep(2),
            .feed(2)
        ).autoCut()
    }

    // MARK: - 刷新小票模型与原生预览模式视图
    private func reloadReceipt(width: Int, playAnimation: Bool = true) {
        currentPaperWidth = width
        let ticket = buildTicket(totalWidth: width)
        currentTicket = ticket
        currentPrintData = ticket.bytes(using: .gbk)
        
        let paperWidth: ReceiptPaperWidth = (width == 32) ? .mm58 : .mm80
        slotWidthConstraint?.constant = (width == 32) ? 320 : 400
        
        if let existingPreview = receiptPreviewView {
            existingPreview.paperWidth = paperWidth
            existingPreview.updateTicket(ticket)
        } else {
            let preview = ticket.preview(paperWidth: paperWidth)
            preview.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(preview)
            receiptPreviewView = preview
            
            NSLayoutConstraint.activate([
                preview.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
                preview.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                preview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
            ])
        }
        
        if playAnimation {
            triggerPaperFeedAnimation()
        } else {
            // 尚未开始出纸：小票隐藏在出纸口内部，展示待命卡片，绝不提前暴露最前面内容
            receiptPreviewView?.isHidden = true
            idlePlaceholderView.isHidden = false
        }
    }

    // MARK: - 交互动作响应
    
    @objc private func onSegmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 2 {
            reloadReceiptWithJSON()
        } else {
            let width = sender.selectedSegmentIndex == 0 ? 32 : 48
            reloadReceipt(width: width, playAnimation: true)
        }
    }
    
    private func reloadReceiptWithJSON() {
        let jsonString = """
        {
          "autoCut": true,
          "autoInitialize": true,
          "chunks": [
            { "type": "text", "content": "JSON 动态下发小票", "bold": true, "alignment": "center" },
            { "type": "splitter", "char": "=" },
            { "type": "twoColumn", "left": "订单号", "right": "JSON-001" },
            { "type": "twoColumn", "left": "支付方式", "right": "微信支付" },
            { "type": "splitter", "char": "-" },
            { "type": "threeColumn", "col1": "云端动态商品名", "col2": "x2", "col3": "19.90", "wrap": true },
            { "type": "threeColumn", "col1": "附加服务费", "col2": "x1", "col3": "2.00", "wrap": true },
            { "type": "splitter", "char": "-" },
            { "type": "twoColumn", "left": "总计", "right": "￥21.90" },
            { "type": "text", "content": "扫码获取电子发票", "alignment": "center" },
            { "type": "qrcode", "content": "https://json.example.com" },
            { "type": "barcode", "content": "666888", "barcodeType": "code128" },
            { "type": "text", "content": "本小票完全由纯 JSON 文本驱动生成\\n告别硬编码！", "alignment": "center" },
            { "type": "feed", "lines": 3 },
            { "type": "buzzer", "times": 1 }
          ]
        }
        """
        
        do {
            let ticket = try Ticket(json: jsonString)
            currentPaperWidth = 32
            currentTicket = ticket
            currentPrintData = ticket.bytes(using: .gbk)
            slotWidthConstraint?.constant = 320
            
            if let existingPreview = receiptPreviewView {
                existingPreview.paperWidth = .mm58
                existingPreview.updateTicket(ticket)
            }
            triggerPaperFeedAnimation()
        } catch {
            showAlert("JSON 解析失败", "\(error)")
        }
    }

    /// 演示主项目调用者如何将 ticket.previewView 嵌入到自己的弹窗或自定义 UI 中
    @objc private func onOpenPreviewModeTapped() {
        guard let ticket = currentTicket else { return }
        let width: ReceiptPaperWidth = (currentPaperWidth == 32) ? .mm58 : .mm80
        
        let modalVC = UIViewController()
        modalVC.view.backgroundColor = UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
        modalVC.title = "主项目自定义弹窗预览"
        
        let modalScroll = UIScrollView()
        modalScroll.translatesAutoresizingMaskIntoConstraints = false
        modalScroll.alwaysBounceVertical = true
        modalVC.view.addSubview(modalScroll)
        
        // 主项目调用者直接获取纯净的 previewView 嵌入自己的任何容器中
        let preview = ticket.previewView(paperWidth: width)
        preview.translatesAutoresizingMaskIntoConstraints = false
        modalScroll.addSubview(preview)
        
        NSLayoutConstraint.activate([
            modalScroll.topAnchor.constraint(equalTo: modalVC.view.safeAreaLayoutGuide.topAnchor),
            modalScroll.leadingAnchor.constraint(equalTo: modalVC.view.leadingAnchor),
            modalScroll.trailingAnchor.constraint(equalTo: modalVC.view.trailingAnchor),
            modalScroll.bottomAnchor.constraint(equalTo: modalVC.view.bottomAnchor),
            
            preview.topAnchor.constraint(equalTo: modalScroll.topAnchor, constant: 20),
            preview.centerXAnchor.constraint(equalTo: modalScroll.centerXAnchor),
            preview.bottomAnchor.constraint(equalTo: modalScroll.bottomAnchor, constant: -20)
        ])
        
        let nav = UINavigationController(rootViewController: modalVC)
        modalVC.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .done, target: self, action: #selector(dismissModal))
        present(nav, animated: true)
    }
    
    @objc private func dismissModal() {
        dismiss(animated: true)
    }

    /// 导出小票高清长图 (通过 ticket.previewImage 纯净导出)
    @objc private func onExportImageTapped() {
        guard let ticket = currentTicket else { return }
        let width: ReceiptPaperWidth = (currentPaperWidth == 32) ? .mm58 : .mm80
        
        // 调用原生 image 导出长图
        guard let image = ticket.image(paperWidth: width) else { return }
        
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 100, width: 0, height: 0)
        }
        present(activityVC, animated: true, completion: nil)
    }

    /// 模拟真实热敏打印机“吱——吱——吱——”机械步进出纸动效
    @objc private func onPrintSimulationTapped() {
        triggerPaperFeedAnimation()
    }
    
    private func triggerPaperFeedAnimation() {
        guard !isPrinting else { return }
        guard let preview = receiptPreviewView else { return }
        
        // 1. 隐藏待命占位卡片，将小票展现
        idlePlaceholderView.isHidden = true
        preview.isHidden = false
        preview.alpha = 1.0
        
        view.layoutIfNeeded()
        let fullHeight = preview.bounds.height > 0 ? preview.bounds.height : 600
        
        isPrinting = true
        scrollView.setContentOffset(.zero, animated: false)
        
        // 彻底移除 Mask，利用 scrollView 的 clipsToBounds。
        // 将小票整体向上平移 fullHeight，完全藏在出纸口(scrollView 顶部)之外！
        preview.layer.mask = nil
        preview.transform = CGAffineTransform(translationX: 0, y: -fullHeight)
        
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.prepare()
        
        // 结构化定义热敏打印机电机“吱——吱——吱——”每一次步进脉冲：
        struct FeedPulse {
            let targetFraction: CGFloat    // 到达的累计高度比例
            let moveDuration: TimeInterval  // 齿轮转动推进用时
            let pauseDuration: TimeInterval // 换行打印加热停顿用时
        }
        
        let pulses: [FeedPulse] = [
            FeedPulse(targetFraction: 0.10, moveDuration: 0.08, pauseDuration: 0.12), // 1
            FeedPulse(targetFraction: 0.20, moveDuration: 0.06, pauseDuration: 0.10), // 2
            FeedPulse(targetFraction: 0.32, moveDuration: 0.05, pauseDuration: 0.09), // 3
            FeedPulse(targetFraction: 0.44, moveDuration: 0.05, pauseDuration: 0.08), // 4
            FeedPulse(targetFraction: 0.55, moveDuration: 0.05, pauseDuration: 0.08), // 5
            FeedPulse(targetFraction: 0.68, moveDuration: 0.06, pauseDuration: 0.11), // 6
            FeedPulse(targetFraction: 0.82, moveDuration: 0.10, pauseDuration: 0.13), // 7
            FeedPulse(targetFraction: 0.94, moveDuration: 0.07, pauseDuration: 0.09), // 8
            FeedPulse(targetFraction: 1.00, moveDuration: 0.08, pauseDuration: 0.05), // 9
        ]
        
        var pulseIndex = 0
        
        func executePulse() {
            guard pulseIndex < pulses.count else {
                // 全部脉冲步进走纸完成
                self.isPrinting = false
                preview.transform = .identity
                
                let cutHaptic = UIImpactFeedbackGenerator(style: .heavy)
                cutHaptic.impactOccurred()
                AudioServicesPlaySystemSound(1104) // 真实切纸咔嗒声
                return
            }
            
            let pulse = pulses[pulseIndex]
            let targetY = -fullHeight + (fullHeight * pulse.targetFraction)
            
            haptic.impactOccurred()
            AudioServicesPlaySystemSound(1104)
            
            // 核心物理动效：“纸张从顶部慢慢向下出来”
            // 整张纸真正往下移动！
            UIView.animate(withDuration: pulse.moveDuration, delay: 0, options: .curveEaseOut, animations: {
                preview.transform = CGAffineTransform(translationX: 0, y: targetY)
            }, completion: { _ in
                pulseIndex += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + pulse.pauseDuration) { [weak self] in
                    guard self?.isPrinting == true else { return }
                    executePulse()
                }
            })
        }
        
        // 触发第一次步进
        executePulse()
    }

    /// 查看当前小票编译出的十六进制 ESC/POS 指令流
    @objc private func onInspectBytesTapped() {
        let totalCount = currentPrintData.count
        let hexString = currentTicket?.hexDump(using: .gbk) ?? ""
        
        let alert = UIAlertController(
            title: "ESC/POS 二进制指令流",
            message: "已成功编译生成标准小票字节：\(totalCount) 字节\n\n前 100 字节预览：\n" + String(hexString.prefix(280)) + "...",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "复制全部 Hex", style: .default) { _ in
            UIPasteboard.general.string = hexString
        })
        alert.addAction(UIAlertAction(title: "确定", style: .cancel))
        present(alert, animated: true)
    }

    /// 局域网 Socket 直连发送到真实小票打印机（9100 端口）
    @objc private func onNetworkPrintTapped() {
        let alert = UIAlertController(title: "局域网小票机直连打印", message: "请输入打印机局域网 IP 地址（默认 9100 端口）", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "例如 192.168.1.200"
            tf.text = "192.168.1.200"
            tf.keyboardType = .numbersAndPunctuation
        }
        alert.addAction(UIAlertAction(title: "发送打印", style: .default) { [weak self] _ in
            guard let self = self, let ip = alert.textFields?.first?.text, !ip.isEmpty else { return }
            self.sendDataToPrinter(ip: ip, port: 9100, data: self.currentPrintData)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func onQueuePrintTapped() {
        guard let ticket = currentTicket else { return }
        print("--- 准备并发提交两张小票任务 ---")
        
        let mockTransport = MockTransport()
        
        demoPrintQueue.async {
            ticket.print(to: mockTransport)
        }
        
        demoPrintQueue.async {
            ticket.print(to: mockTransport)
        }
        
        showAlert("队列测试", "已同时将两张小票压入外部队列。\n请查看 Xcode 控制台输出，验证线程是否按顺序串行处理。")
    }
    
    @objc private func onCheckStatusTapped() {
        // 模拟硬件发回的状态字节，比如机盖开启(0x04) + 缺纸(0x60) = 0x64
        let mockStatusByte: UInt8 = 0x64
        let status = PrinterHardwareStatus.parse(byte: mockStatusByte)
        
        let msg = """
        主动发出的轮询指令: Data.checkPaperStatus
        
        收到硬件反馈字节: \(String(format: "0x%02X", mockStatusByte))
        解析出包含异常: \(status.description)
        可否打印 (isNormal): \(status.isNormal)
        """
        showAlert("打印机状态硬件回调解析", msg)
    }

    private func sendDataToPrinter(ip: String, port: UInt16, data: Data) {
        let host = NWEndpoint.Host(ip)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let conn = NWConnection(host: host, port: nwPort, using: .tcp)
        
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                conn.send(content: data, completion: .contentProcessed { err in
                    DispatchQueue.main.async {
                        if let err = err {
                            self?.showAlert("发送失败", "\(err)")
                        } else {
                            self?.showAlert("发送成功", "🎉 打印指令已成功写入打印机！")
                        }
                        conn.cancel()
                    }
                })
            case .failed(let err):
                DispatchQueue.main.async {
                    self?.showAlert("连接失败", "无法连接到 \(ip):9100: \(err)")
                    conn.cancel()
                }
            default:
                break
            }
        }
        conn.start(queue: .main)
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 界面布局搭建
    private func setupUI() {
        top?.isHidden = true
        bottom?.isHidden = true
        view.backgroundColor = UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
        
        // 顶部纸宽切换
        segmentWidth.selectedSegmentIndex = 0
        segmentWidth.addTarget(self, action: #selector(onSegmentChanged), for: .valueChanged)
        segmentWidth.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentWidth)
        
        // 滚动视图（承载完整的拟物化打印机实体与小票数据）
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // 模拟打印机出纸口黑槽 (绝对固定在 view 上方，置于最顶层，不随滚动而移动)
        printerSlotView.backgroundColor = UIColor(white: 0.16, alpha: 1.0)
        printerSlotView.layer.cornerRadius = 6
        printerSlotView.layer.borderWidth = 1.0
        printerSlotView.layer.borderColor = UIColor(white: 0.08, alpha: 1.0).cgColor
        printerSlotView.layer.shadowColor = UIColor.black.cgColor
        printerSlotView.layer.shadowOpacity = 0.25
        printerSlotView.layer.shadowRadius = 4
        printerSlotView.layer.shadowOffset = CGSize(width: 0, height: 2)
        printerSlotView.layer.zPosition = 999 // 绝对固定在最顶层
        printerSlotView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(printerSlotView)
        
        // 出纸口内部缝隙细槽
        let slitLine = UIView()
        slitLine.backgroundColor = .black
        slitLine.layer.cornerRadius = 1.5
        slitLine.translatesAutoresizingMaskIntoConstraints = false
        printerSlotView.addSubview(slitLine)
        
        let slotW = printerSlotView.widthAnchor.constraint(equalToConstant: 320)
        self.slotWidthConstraint = slotW
        slotW.isActive = true
        
        // 滚动区域（顶部从固定出纸槽正下方开始，小票上滑时自然隐入出纸口深处，绝不穿透跑偏）
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.clipsToBounds = true
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // 打印机空闲待机提示卡片（尚未打印时展示，保证出纸口下方不提前泄露小票内容）
        idlePlaceholderView.backgroundColor = .white
        idlePlaceholderView.layer.cornerRadius = 12
        idlePlaceholderView.layer.borderWidth = 1.0
        idlePlaceholderView.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor
        idlePlaceholderView.layer.shadowColor = UIColor.black.cgColor
        idlePlaceholderView.layer.shadowOpacity = 0.04
        idlePlaceholderView.layer.shadowRadius = 8
        idlePlaceholderView.layer.shadowOffset = CGSize(width: 0, height: 2)
        idlePlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(idlePlaceholderView)
        
        let iconLabel = UILabel()
        iconLabel.text = "🖨️"
        iconLabel.font = .systemFont(ofSize: 40)
        iconLabel.textAlignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = "热敏打印机已就绪"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .darkGray
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "小票数据准备完毕\n点击下方【🖨️ 模拟出纸】体验步进走纸动效"
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .lightGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        let idleStack = UIStackView(arrangedSubviews: [iconLabel, titleLabel, subtitleLabel])
        idleStack.axis = .vertical
        idleStack.spacing = 8
        idleStack.alignment = .center
        idleStack.translatesAutoresizingMaskIntoConstraints = false
        idlePlaceholderView.addSubview(idleStack)
        
        NSLayoutConstraint.activate([
            idlePlaceholderView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            idlePlaceholderView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            idlePlaceholderView.widthAnchor.constraint(equalToConstant: 280),
            idlePlaceholderView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40),
            
            idleStack.topAnchor.constraint(equalTo: idlePlaceholderView.topAnchor, constant: 24),
            idleStack.bottomAnchor.constraint(equalTo: idlePlaceholderView.bottomAnchor, constant: -24),
            idleStack.leadingAnchor.constraint(equalTo: idlePlaceholderView.leadingAnchor, constant: 16),
            idleStack.trailingAnchor.constraint(equalTo: idlePlaceholderView.trailingAnchor, constant: -16),
        ])
        
        // 操作功能按钮栏 (双行工具栏)
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.distribution = .fillEqually
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        // 第一行按钮：预览模式 + 导出长图 + 状态测试
        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.distribution = .fillEqually
        row1.spacing = 8
        
        let previewModeBtn = createButton(title: "📱 弹窗预览模式", bg: UIColor(red: 0.12, green: 0.47, blue: 0.95, alpha: 1.0), titleColor: .white, action: #selector(onOpenPreviewModeTapped))
        let exportImageBtn = createButton(title: "🖼️ 导出长图", bg: .white, titleColor: .darkGray, action: #selector(onExportImageTapped))
        let checkStatusBtn = createButton(title: "🛠️ 状态回调测试", bg: .white, titleColor: .darkGray, action: #selector(onCheckStatusTapped))
        row1.addArrangedSubview(previewModeBtn)
        row1.addArrangedSubview(exportImageBtn)
        row1.addArrangedSubview(checkStatusBtn)
        
        // 第二行按钮：模拟出纸 + 指令流 + 网络打印
        let row2 = UIStackView()
        row2.axis = .horizontal
        row2.distribution = .fillEqually
        row2.spacing = 8
        
        let printSimBtn = createButton(title: "🖨️ 模拟出纸", bg: .white, titleColor: .darkGray, action: #selector(onPrintSimulationTapped))
        let inspectBtn = createButton(title: "🔍 指令流", bg: .white, titleColor: .darkGray, action: #selector(onInspectBytesTapped))
        let netBtn = createButton(title: "📶 局域网", bg: .white, titleColor: .darkGray, action: #selector(onNetworkPrintTapped))
        let queueBtn = createButton(title: "🔄 并发测试", bg: .white, titleColor: .darkGray, action: #selector(onQueuePrintTapped))
        row2.addArrangedSubview(printSimBtn)
        row2.addArrangedSubview(inspectBtn)
        row2.addArrangedSubview(netBtn)
        row2.addArrangedSubview(queueBtn)
        
        mainStack.addArrangedSubview(row1)
        mainStack.addArrangedSubview(row2)
        
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            // 分段选择器
            segmentWidth.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            segmentWidth.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentWidth.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // 模拟打印机出纸口槽位 (绝对固定在屏幕上方)
            printerSlotView.topAnchor.constraint(equalTo: segmentWidth.bottomAnchor, constant: 10),
            printerSlotView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            printerSlotView.heightAnchor.constraint(equalToConstant: 16),
            
            slitLine.centerYAnchor.constraint(equalTo: printerSlotView.centerYAnchor),
            slitLine.leadingAnchor.constraint(equalTo: printerSlotView.leadingAnchor, constant: 12),
            slitLine.trailingAnchor.constraint(equalTo: printerSlotView.trailingAnchor, constant: -12),
            slitLine.heightAnchor.constraint(equalToConstant: 3),
            
            // 滚动区域（顶部从固定出纸槽正下方无缝承接）
            scrollView.topAnchor.constraint(equalTo: printerSlotView.bottomAnchor, constant: -4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: mainStack.topAnchor, constant: -10),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 底部操作栏
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            mainStack.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -8),
            mainStack.heightAnchor.constraint(equalToConstant: 92)
        ])
    }
    
    private func createButton(title: String, bg: UIColor, titleColor: UIColor, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        btn.backgroundColor = bg
        btn.setTitleColor(titleColor, for: .normal)
        btn.layer.cornerRadius = 8
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.05
        btn.layer.shadowRadius = 3
        btn.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
    
    /// 动态生成一个高保真餐饮黑白品牌 Logo 图案（作为备选图案资源）
    private func makeDemoLogoImage() -> UIImage? {
        let size = CGSize(width: 260, height: 80)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            
            // 外圈圆角线框
            let frameRect = CGRect(x: 4, y: 4, width: size.width - 8, height: size.height - 8)
            let path = UIBezierPath(roundedRect: frameRect, cornerRadius: 8)
            cgCtx.setStrokeColor(UIColor.black.cgColor)
            cgCtx.setLineWidth(2.0)
            path.stroke()
            
            // 品牌英文字符
            let title = "★ WEIMEI RESTAURANT ★"
            let font = UIFont.systemFont(ofSize: 14, weight: .black)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]
            let textSize = (title as NSString).size(withAttributes: attrs)
            let textOrigin = CGPoint(x: (size.width - textSize.width) / 2, y: 16)
            (title as NSString).draw(at: textOrigin, withAttributes: attrs)
            
            // 下方副标
            let sub = "AUTHENTIC QUALITY • SINCE 2026"
            let subFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: UIColor.darkGray
            ]
            let subSize = (sub as NSString).size(withAttributes: subAttrs)
            let subOrigin = CGPoint(x: (size.width - subSize.width) / 2, y: 44)
            (sub as NSString).draw(at: subOrigin, withAttributes: subAttrs)
        }
    }
}
