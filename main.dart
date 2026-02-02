import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(DividendCalcApp());

class DividendCalcApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '基金配息試算',
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
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      exchangeRateController.text = prefs.getString('saved_rate') ?? "31.5";
      navController.text = prefs.getString('saved_nav') ?? "";
      divController.text = prefs.getString('saved_div') ?? "";
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_rate', exchangeRateController.text);
    await prefs.setString('saved_nav', navController.text);
    await prefs.setString('saved_div', divController.text);
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      setState(() => result = "無法開啟網頁");
    }
  }

  void runCalculation() {
    _saveData();
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
        result = "【台幣投入結論】\n手續費率：${(feeRate * 100).toInt()}%\n淨投入金額：${netPremium.toStringAsFixed(0)} TWD\n購入單位數：${units.toStringAsFixed(4)}\n-----------------------------------\n預計每月領取：${monthlyTWD.toStringAsFixed(0)} TWD\n預計每年合計：${yearlyTWD.toStringAsFixed(0)} TWD";
      } else {
        result = "【美元投入結論】\n手續費率：${(feeRate * 100).toInt()}%\n淨投入金額：${netPremium.toStringAsFixed(2)} USD\n購入單位數：${units.toStringAsFixed(4)}\n-----------------------------------\n預計每月領取：${monthlyUSD.toStringAsFixed(2)} USD\n(約合台幣：${monthlyTWD.toStringAsFixed(0)} TWD)\n\n預計每年合計：${yearlyUSD.toStringAsFixed(2)} USD\n(約合台幣：${yearlyTWD.toStringAsFixed(0)} TWD)";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('專業配息試算系統'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            SegmentedButton<String>(
              segments: [ButtonSegment(value: 'TWD', label: Text('台幣版')), ButtonSegment(value: 'USD', label: Text('美元版'))],
              selected: {selectedCurrency},
              onSelectionChanged: (val) => setState(() => selectedCurrency = val.first),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<Map<String, dynamic>>(
              decoration: InputDecoration(labelText: "1. 選擇標的", border: OutlineInputBorder()),
              value: selectedFund,
              items: fundOptions.map((f) => DropdownMenuItem(value: f, child: Text(f['name'], style: TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                setState(() {
                  selectedFund = val;
                  divController.text = val!['defaultDiv'];
                  _launchUrl(val['url']!);
                });
              },
            ),
            SizedBox(height: 15),
            TextField(controller: premiumController, decoration: InputDecoration(labelText: "投入保費 ($selectedCurrency)", border: OutlineInputBorder()), keyboardType: TextInputType.number),
            SizedBox(height: 15),
            TextField(controller: exchangeRateController, decoration: InputDecoration(labelText: "參考匯率 (USD/TWD)", border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => _saveData()),
            SizedBox(height: 15),
            TextField(controller: navController, decoration: InputDecoration(labelText: "當前淨值 (USD)", border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => _saveData()),
            SizedBox(height: 15),
            TextField(controller: divController, decoration: InputDecoration(labelText: "單位配息 (USD)", border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => _saveData()),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.blueGrey),
              onPressed: runCalculation,
              child: Text("執行試算", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            SizedBox(height: 20),
            Container(width: double.infinity, padding: EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)), child: Text(result)),
          ],
        ),
      ),
    );
  }
}
