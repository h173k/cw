import UIKit
import CakeWalletLib
import CakeWalletCore
import FlexLayout
import SwiftyJSON
import SwipeCellKit


final class TradeTableCell: FlexCell {
    static let height = 56 as CGFloat
    let idLabel = UILabel()
    let dateLabel = UILabel()
    let leftViewWrapper = UIView()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    override func configureView() {
        super.configureView()
        contentView.layer.masksToBounds = false
        contentView.backgroundColor = .white
        backgroundColor = .clear
        selectionStyle = .none
        
        idLabel.font = applyFont(ofSize: 16)
        dateLabel.font = applyFont(ofSize: 16)
    }
    
    override func configureConstraints() {
        super.configureConstraints()
        
        contentView.flex
            .direction(.row).alignItems(.center)
            .height(AddressTableCell.height).width(100%)
            .padding(5, 15, 5, 15)
            .define { flex in
                flex.addItem(leftViewWrapper).define({ wrapperFlex in
                    wrapperFlex.addItem(idLabel)
                    wrapperFlex.addItem(dateLabel)
                })
        }
    }
    
    func configure(tradeID: String, date: Double, provider: String) {
        idLabel.text = tradeID
        idLabel.flex.markDirty()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy HH:mm"
        
        dateLabel.text = dateFormatter.string(from: Date(timeIntervalSince1970: date))
        dateLabel.flex.markDirty()
        contentView.flex.layout()
    }
}

struct TradeInfo: JSONInitializable {
    let tradeID: String
    let date: Double
    var provider: String

    init(json: JSON) {
        tradeID = json["tradeID"].stringValue
        date = json["date"].doubleValue
        provider = json["provider"].stringValue
    }
}

extension TradeInfo: CellItem {
    func setup(cell: TradeTableCell) {
        cell.configure(
            tradeID: tradeID,
            date: date,
            provider: provider
        )
    }
}


final class TradesHistoryViewController: BaseViewController<TradesHistoryView>, UITableViewDelegate, UITableViewDataSource {
    weak var exchangeFlow: ExchangeFlow?
    private var trades: [TradeInfo] = []
    
    init(exchangeFlow: ExchangeFlow?) {
        self.exchangeFlow = exchangeFlow
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadTrades()
    }
    
    override func configureBinds() {
        super.configureBinds()
        title = "Trades history"
        
        let backButton = UIBarButtonItem(title: "", style: .plain, target: self, action: nil)
        navigationItem.backBarButtonItem = backButton
        
        contentView.table.delegate = self
        contentView.table.dataSource = self
        contentView.table.register(items: [TradeInfo.self])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView.backgroundView = trades.count == 0 ? createNoDataLabel(with: tableView.bounds.size) : nil
        tableView.separatorStyle = .none
        
        return trades.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let trade = trades[indexPath.row]
        let cell = tableView.dequeueReusableCell(withItem: trade, for: indexPath) as! SwipeTableViewCell
        
        cell.delegate = self as? SwipeTableViewCellDelegate
        cell.addSeparator()
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return AddressTableCell.height
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let trade = trades[indexPath.row]
        
        exchangeFlow?.change(route: .tradeDetails(trade))
    }
    
    private func loadTrades() {
        guard let tradesJSON = ExchangeTransactions.shared.getAll() else { return }
        
        for tradeJSON in tradesJSON {
            let trade = TradeInfo(json: tradeJSON)
            trades.append(trade)
        }
    }
    
    private func createNoDataLabel(with size: CGSize) -> UIView {
        let noDataLabel: UILabel = UILabel(frame: CGRect(origin: .zero, size: size))
        noDataLabel.text = "No trades yet"
        noDataLabel.textColor = UIColor(hex: 0x9bacc5)
        noDataLabel.textAlignment = .center
        
        return noDataLabel
    }
}
