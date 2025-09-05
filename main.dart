
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  runApp(const LagnApp());
}

const String kApiBase = 'https://live.betablaster.in/api/send';
const String kInstanceId = '6881CE8BC1285';
const String kAccessToken = '6881cc07a4e27';
const String kBrand = 'मॅरेज बिरो विवाह कंपनी सातारा';
final DateFormat kDf = DateFormat('dd-MM-yyyy');

class LagnApp extends StatelessWidget {
  const LagnApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Lagn', theme: ThemeData(useMaterial3: true), home: const HomeScreen());
  }
}

class Client {
  int? id;
  String idNo;
  String name;
  String mobile;
  String staffName;
  DateTime nextVisit;
  String intake;
  DateTime createdAt;
  DateTime updatedAt;
  Client({this.id, required this.idNo, required this.name, required this.mobile, required this.staffName,
    required this.nextVisit, required this.intake, DateTime? createdAt, DateTime? updatedAt})
    : createdAt = createdAt ?? DateTime.now(), updatedAt = updatedAt ?? DateTime.now();
  Map<String, Object?> toMap() => {
    'id': id, 'idNo': idNo, 'name': name, 'mobile': mobile, 'staffName': staffName,
    'nextVisit': nextVisit.millisecondsSinceEpoch, 'intake': intake,
    'createdAt': createdAt.millisecondsSinceEpoch, 'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
  static Client fromMap(Map<String, Object?> m) => Client(
    id: m['id'] as int?, idNo: m['idNo'] as String, name: m['name'] as String, mobile: m['mobile'] as String,
    staffName: m['staffName'] as String, nextVisit: DateTime.fromMillisecondsSinceEpoch(m['nextVisit'] as int),
    intake: m['intake'] as String, createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
  );
}

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'lagn.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE clients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          idNo TEXT NOT NULL,
          name TEXT NOT NULL,
          mobile TEXT NOT NULL,
          staffName TEXT NOT NULL,
          nextVisit INTEGER NOT NULL,
          intake TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
    });
  }
  Database get db => _db!;
  Future<int> insertClient(Client c) async => db.insert('clients', c.toMap());
  Future<int> updateClient(Client c) async { c.updatedAt = DateTime.now(); return db.update('clients', c.toMap(), where: 'id=?', whereArgs: [c.id]); }
  Future<List<Client>> allClients() async => (await db.query('clients', orderBy: 'createdAt DESC')).map((e)=>Client.fromMap(e)).toList();
  Future<List<Client>> clientsForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.query('clients', where: 'nextVisit >= ? AND nextVisit < ?', whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch], orderBy: 'nextVisit ASC');
    return rows.map((e)=>Client.fromMap(e)).toList();
  }
  Future<List<Client>> search(String q) async {
    final like = '%$q%';
    final rows = await db.query('clients', where: 'idNo LIKE ? OR name LIKE ? OR mobile LIKE ?', whereArgs: [like, like, like], orderBy: 'createdAt DESC');
    return rows.map((e)=>Client.fromMap(e)).toList();
  }
  Future<int> count() async { final res = await db.rawQuery('SELECT COUNT(*) AS c FROM clients;'); return (res.first['c'] as int?) ?? 0; }
}

class ApiService {
  static String _normalize(String mobile) {
    final d = mobile.replaceAll(RegExp(r'\D'), '');
    return d.startsWith('91') ? d : '91$d';
  }
  static Future<bool> sendText({required String mobile, required String message}) async {
    final uri = Uri.parse(kApiBase).replace(queryParameters: {
      'number': _normalize(mobile), 'type': 'text', 'message': message, 'instance_id': kInstanceId, 'access_token': kAccessToken,
    });
    try { final r = await http.get(uri); return r.statusCode == 200; } catch (_) { return false; }
  }
  static Future<void> sendOnSubmit({required Client c}) async {
    final a = '✨ *अभिनंदन!* ✨\nआपले रजिस्ट्रेशन यशस्वी झाले आहे.\n*${kBrand}* आपली सेवा तत्काळ सुरू करत आहे.\nधन्यवाद!';
    final b = '📅 *पुढील भेट:* ${kDf.format(c.nextVisit)}\nकाही बदल असल्यास कृपया कळवा.\n— *$kBrand*';
    await sendText(mobile: c.mobile, message: a); await sendText(mobile: c.mobile, message: b);
  }
  static Future<void> sendNextVisit({required Client c}) async {
    final m = '📅 *अपडेटेड पुढील भेट:* ${kDf.format(c.nextVisit)}\nकाही बदल असल्यास कृपया कळवा.\n— *$kBrand*';
    await sendText(mobile: c.mobile, message: m);
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = [
      _HomeItem('New Form', Icons.note_add, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewFormScreen()))),
      _HomeItem('Today List', Icons.today, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodayListScreen()))),
      _HomeItem('Report', Icons.bar_chart, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()))),
      _HomeItem('Search', Icons.search, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Lagn — Main Menu')),
      body: GridView.count(crossAxisCount: 2, padding: const EdgeInsets.all(16), children: [
        for (final i in items) Card(child: InkWell(onTap: i.onTap, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(i.icon, size: 40), const SizedBox(height: 8), Text(i.title, style: const TextStyle(fontWeight: FontWeight.w600))]))))
      ]),
    );
  }
}
class _HomeItem { final String title; final IconData icon; final VoidCallback onTap; _HomeItem(this.title, this.icon, this.onTap); }

class NewFormScreen extends StatefulWidget { const NewFormScreen({super.key}); @override State<NewFormScreen> createState()=>_NewFormScreenState(); }
class _NewFormScreenState extends State<NewFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNo = TextEditingController(), _name = TextEditingController(), _mobile = TextEditingController(),
        _staff = TextEditingController(), _intake = TextEditingController();
  DateTime? _nextVisit;
  @override void dispose(){ _idNo.dispose(); _name.dispose(); _mobile.dispose(); _staff.dispose(); _intake.dispose(); super.dispose(); }
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365*3)), initialDate: _nextVisit ?? now);
    if (d!=null) setState(()=>_nextVisit=d);
  }
  Future<void> _submit() async {
    if(!_formKey.currentState!.validate()||_nextVisit==null){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया सर्व माहिती वैध भरा आणि तारीख निवडा.'))); return; }
    final c = Client(idNo:_idNo.text.trim(), name:_name.text.trim(), mobile:_mobile.text.trim(), staffName:_staff.text.trim(), nextVisit:_nextVisit!, intake:_intake.text.trim());
    final id = await DatabaseService.instance.insertClient(c);
    if(id>0){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('क्लायंट सेव्ह झाला. मेसेज पाठवत आहोत…')));
      await ApiService.sendOnSubmit(c:c); if(!mounted)return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('अभिनंदन + पुढील भेट मेसेज पाठवला.'))); Navigator.pop(context);
    } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('सेव्ह करताना त्रुटी. पुन्हा प्रयत्न करा.'))); }
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('New Form')), body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Form(key:_formKey, child: Column(children:[
      _tf(_idNo,'ID No',vReq), _tf(_name,'Name',vReq), _tf(_mobile,'Mobile',vMobile), _tf(_staff,'Staff Name',vReq), _dateField(context), _tf(_intake,'Intake',vReq),
      const SizedBox(height:12), SizedBox(width:double.infinity, child: FilledButton(onPressed:_submit, child: const Text('Submit'))),
    ]))));
  }
  Widget _dateField(BuildContext context){ final t=_nextVisit==null?'Select Next Visit Date':kDf.format(_nextVisit!);
    return ListTile(contentPadding: EdgeInsets.zero, title: const Text('Next Visit Date'), subtitle: Text(t), trailing: const Icon(Icons.calendar_month), onTap:_pickDate);
  }
  Widget _tf(TextEditingController c,String label,String? Function(String?) v){ return Padding(padding: const EdgeInsets.only(bottom:12), child: TextFormField(controller:c, decoration: InputDecoration(labelText:label, border: const OutlineInputBorder()), validator:v)); }
}

class TodayListScreen extends StatefulWidget { const TodayListScreen({super.key}); @override State<TodayListScreen> createState()=>_TodayListScreenState(); }
class _TodayListScreenState extends State<TodayListScreen> {
  late Future<List<Client>> _f;
  @override void initState(){ super.initState(); _f = DatabaseService.instance.clientsForDate(DateTime.now()); }
  Future<void> _editDate(Client c) async {
    final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365*3)), initialDate: c.nextVisit);
    if(d!=null){ c.nextVisit=d; await DatabaseService.instance.updateClient(c);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('तारीख अपडेट झाली. मेसेज पाठवत आहोत…')));
      await ApiService.sendNextVisit(c:c);
      if(mounted){ setState(()=>_f = DatabaseService.instance.clientsForDate(DateTime.now())); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('अपडेटेड Next-Visit मेसेज पाठवला.'))); }
    }
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Today List')), body: FutureBuilder(future:_f, builder:(context,snap){
      if(!snap.hasData) return const Center(child:CircularProgressIndicator());
      final list = snap.data as List<Client>;
      if(list.isEmpty) return const Center(child: Text('आज कोणतीही नियोजित भेट नाही.'));
      return ListView.builder(itemCount:list.length, itemBuilder:(_,i){ final c=list[i];
        return Card(child: ListTile(title: Text('${c.name}  •  ${c.mobile}'), subtitle: Text('ID: ${c.idNo}\nStaff: ${c.staffName}\nIntake: ${c.intake}\nNext: ${kDf.format(c.nextVisit)}'), isThreeLine:true, trailing: IconButton(icon: const Icon(Icons.edit), onPressed: ()=>_editDate(c))));
      });
    }));
  }
}

class ReportScreen extends StatefulWidget { const ReportScreen({super.key}); @override State<ReportScreen> createState()=>_ReportScreenState(); }
class _ReportScreenState extends State<ReportScreen> {
  int _count=0; List<Client> _list=[];
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async { final c=await DatabaseService.instance.count(); final l=await DatabaseService.instance.allClients(); setState(()=>{_count=c, _list=l}); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Report')), body: Column(children:[
      Padding(padding: const EdgeInsets.all(12), child: Row(children:[ const Text('Total Clients: ', style: TextStyle(fontWeight: FontWeight.w600)), Text('$_count') ])),
      Expanded(child: ListView.builder(itemCount:_list.length, itemBuilder:(_,i){ final c=_list[i]; return ListTile(title: Text('${c.name}  •  ${c.mobile}'), subtitle: Text('ID: ${c.idNo}, Staff: ${c.staffName}, Next: ${kDf.format(c.nextVisit)}')); }))
    ]));
  }
}

class SearchScreen extends StatefulWidget { const SearchScreen({super.key}); @override State<SearchScreen> createState()=>_SearchScreenState(); }
class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController(); List<Client> _list=[];
  @override void dispose(){ _q.dispose(); super.dispose(); }
  Future<void> _run() async { final res=await DatabaseService.instance.search(_q.text.trim()); setState(()=>_list=res); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Search')), body: Padding(padding: const EdgeInsets.all(12), child: Column(children:[
      TextField(controller:_q, decoration: InputDecoration(labelText:'Search by ID / Name / Mobile', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed:_run)), onSubmitted: (_)=>_run()),
      const SizedBox(height:12),
      Expanded(child: _list.isEmpty ? const Center(child: Text('काहीही सापडले नाही.')) : ListView.builder(itemCount:_list.length, itemBuilder:(_,i){ final c=_list[i]; return ListTile(title: Text('${c.name}  •  ${c.mobile}'), subtitle: Text('ID: ${c.idNo}, Staff: ${c.staffName}, Next: ${kDf.format(c.nextVisit)}')); }))
    ])));
  }
}

String? vReq(String? v){ if(v==null||v.trim().isEmpty) return 'आवश्यक'; return null; }
String? vMobile(String? v){ if(v==null||v.trim().isEmpty) return 'मोबाइल आवश्यक'; final d=v.replaceAll(RegExp(r'\D'), ''); if(d.length<10) return 'मोबाइल 10 अंकी असावा'; return null; }
