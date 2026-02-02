import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 導入記憶套件

void main() => runApp(DividendCalcApp());

class DividendCalcApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blueGrey, useMaterial3: true),
      home: CalcScreen(),
    );
  }
}

class CalcScreen extends StatefulWidget {
  @override
  _CalcScreenState createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  final TextEditingController premiumController = TextEditingController(); 
  final TextEditingController exchangeRateController = TextEditingController(text: "31.5"); 
  final TextEditingController navController = TextEditingController(); 
  final TextEditingController divController = TextEditingController(); 
  
  String selectedCurrency = "USD"; 
  String result = "請輸入數據並執行試算";

  final List<Map<String, dynamic>> fundOptions = [
    {"name": "安聯收益成長-AM穩定月配息股美元", "url": "https://www.fundswap.com.tw/trade/funds/TF60/", "defaultDiv": "0.055"},
    {"name": "景順環球高評級企業債券E-穩定月配息股美元", "url": "https://www.fundswap.com.tw/trade/funds/IVF2/", "defaultDiv": "0.051"},
  ];

  Map<String, dynamic>? selectedFund;

  @override
  void initState() {
    super.initState();
    _loadSavedData(); // App 一開啟就讀取記憶
  }

  // --- 記憶功能：讀取資料 ---
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      premiumController.text = prefs.getString('saved_premium') ?? "";
      exchangeRateController.text = prefs.getString('saved_rate') ?? "31.5";
      navController.text = prefs.getString('saved_nav') ?? "";
      divController.text = prefs.getString('saved_div') ?? "";
      selectedCurrency = prefs.getString('saved_currency') ?? "USD";
    });
  }

  // --- 記憶功能：儲存資料 ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_premium', premiumController.text);
    await prefs.setString('saved_rate', exchangeRateController.text);
    await prefs.setString('saved_nav', navController.text);
    await prefs.setString('saved_div', divController.text);
    await prefs.setString('saved_currency', selectedCurrency);
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      setState(() => result = "無法開啟網頁，請檢查連線");
    }
  }

  void runCalculation() {
    _saveData(); // 點擊計算時同步存檔
    
    double premium = double.tryParse(premiumController.text) ?? 0;
    double rate = double.tryParse(exchangeRateController.text) ?? 1.0;
    double nav = double.tryParse(navController.text) ?? 0;
    double divPerUnit = double.tryParse(divController.text) ?? 0;

    if (premium <= 0 || nav <= 0 || rate <= 0) {
      setState(() => result = "請完整輸入金額、匯率及淨值");
      return;
    }

    double feeRate;
    if (selectedCurrency == "TWD") {
      if (premium >= 10000000) feeRate = 0.02;
      else if (premium >= 5000000) feeRate = 0.03;
      else if (premium >= 2000000) feeRate = 0.04;
      else feeRate = 0.05;
    } else {
      if (premium >= 333300) feeRate = 0.02;
      else if (premium >= 166600) feeRate = 0.03;
      else if (premium >= 66600) feeRate = 0.04;
      else feeRate = 0.05;
    }

    double feeAmount = premium * feeRate;
    double netPremium = premium - feeAmount;

    double units = (selectedCurrency == "TWD") ? (netPremium / rate) / nav : netPremium / nav;
    double monthlyUSD = units * divPerUnit;
    double monthlyTWD = monthlyUSD * rate;
    double yearlyUSD = monthlyUSD * 12;
    double yearlyTWD = yearlyUSD * rate;

    setState(() {
      if (selectedCurrency == "TWD") {
        result = "【台幣投入】\n手續費率：${(feeRate * 100).toInt()}%\n投入標的金額：${netPremium.toStringAsFixed(0)} TWD\n購入單位數：${units.toStringAsFixed(4)} 單位\n-----------------------------------\n預計每月領取：${monthlyTWD.toStringAsFixed(0)} TWD\n預計每年合計：${yearlyTWD.toStringAsFixed(0)} TWD";
      } else {
        result = "【美元投入】\n手續費率：${(feeRate * 100).toInt()}%\n投入標的金額：${netPremium.toStringAsFixed(2)} USD\n購入單位數：${units.toStringAsFixed(4)} 單位\n-----------------------------------\n預計每月領取：${monthlyUSD.toStringAsFixed(2)} USD\n(約合台幣：${monthlyTWD.toStringAsFixed(0)} TWD)\n\n預計每年合計：${yearlyUSD.toStringAsFixed(2)} USD\n(約合台幣：${yearlyTWD.toStringAsFixed(0)} TWD)";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('保險基金配息試算'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SegmentedButton<String>(
                segments: [ButtonSegment(value: 'TWD', label: Text('台幣版')), ButtonSegment(value: 'USD', label: Text('美元版'))],
                selected: {selectedCurrency},
                onSelectionChanged: (val) => setState(() => selectedCurrency = val.first),
              ),
            ),
            SizedBox(height: 25),
            Text("1. 選擇標的自動帶入配息並確認淨值", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: Colors.orange.shade800, width: 2), borderRadius: BorderRadius.circular(10), color: Colors.orange.shade50),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  hint: Text("點此選擇基金標的", style: TextStyle(color: Colors.orange.shade900)),
                  isExpanded: true,
                  value: selectedFund,
                  items: fundOptions.map((fund) => DropdownMenuItem(value: fund, child: Text(fund['name']!, style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedFund = val;
                      divController.text = val!['defaultDiv'];
                      _launchUrl(val['url']!); 
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 25),
            Text("2. 輸入數據進行試算 (自動記憶中)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
            SizedBox(height: 10),
            inputField(premiumController, "投入保費總額 ($selectedCurrency)"),
            inputField(exchangeRateController, "參考匯率 (USD/TWD)"),
            inputField(navController, "基金當前淨值 (USD)"),
            inputField(divController, "每單位分配金額 (USD)"),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55), backgroundColor: Colors.blueGrey.shade800, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: runCalculation, 
              child: Text("執行試算並儲存數據", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            ),
            SizedBox(height: 25),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueGrey.shade100)),
              child: Text(result, style: TextStyle(fontSize: 17, height: 1.8, fontWeight: FontWeight.w500)),
            )
          ],
        ),
      ),
    );
  }

  Widget inputField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => _saveData(), // 內容變動時也自動存檔
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
      ),
    );
  }
}
