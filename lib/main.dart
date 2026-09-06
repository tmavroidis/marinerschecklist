import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show exit;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/checklist_item.dart';
import 'models/checklist_entry.dart';
import 'services/storage_service.dart';

void main() {
  runApp(const MarinersChecklistApp());
}

class MarinersChecklistApp extends StatelessWidget {
  const MarinersChecklistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mariners Checklist',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _storage = StorageService();
  bool? _isPasswordSet;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isSet = await _storage.isPasswordSet();
    setState(() {
      _isPasswordSet = isSet;
    });
  }

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPasswordSet == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isPasswordSet!) {
      return SetupPasswordScreen(onComplete: () {
        setState(() {
          _isPasswordSet = true;
          _isAuthenticated = true;
        });
      });
    }

    if (!_isAuthenticated) {
      return LoginScreen(onAuthenticated: _onAuthenticated);
    }

    return const MainContainer();
  }
}

class SetupPasswordScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SetupPasswordScreen({super.key, required this.onComplete});

  @override
  State<SetupPasswordScreen> createState() => _SetupPasswordScreenState();
}

class _SetupPasswordScreenState extends State<SetupPasswordScreen> {
  final _controller = TextEditingController();
  final _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set App Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Set a password to protect your checklist data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_controller.text.isNotEmpty) {
                  await _storage.setPassword(_controller.text);
                  widget.onComplete();
                }
              },
              child: const Text('Save Password'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const LoginScreen({super.key, required this.onAuthenticated});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  final _storage = StorageService();
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Enter Password',
                errorText: _error.isEmpty ? null : _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final isValid = await _storage.verifyPassword(_controller.text);
                if (isValid) {
                  widget.onAuthenticated();
                } else {
                  setState(() {
                    _error = 'Incorrect password';
                  });
                }
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    ChecklistPage(),
    ReportsPage(),
    ManageQuestionsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.check_box), label: 'Checklist'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Manage'),
        ],
      ),
    );
  }
}

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  final _storage = StorageService();
  final _inspectorController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<ChecklistItem> _items = [];
  List<String> _inspectors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final questions = await _storage.getQuestions();
    final inspectors = await _storage.getInspectors();
    setState(() {
      _items = questions.map((q) => q.copyWith(isChecked: false)).toList();
      _inspectors = inspectors;
      _isLoading = false;
    });
  }

  Future<void> _saveAndEmail() async {
    if (_inspectorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter inspector name')),
      );
      return;
    }

    final entry = ChecklistEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: _selectedDate,
      inspectorName: _inspectorController.text,
      items: _items,
    );

    await _storage.addEntry(entry);
    await _storage.addInspector(entry.inspectorName);

    // Format Email
    final String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final String subject = 'Mariners Checklist Log - $dateStr - ${entry.inspectorName}';
    final StringBuffer body = StringBuffer();
    body.writeln('Inspection Date: $dateStr');
    body.writeln('Inspector: ${entry.inspectorName}');
    body.writeln('\nChecklist Items:');
    for (var item in entry.items) {
      body.writeln('${item.isChecked ? "[X]" : "[ ]"} ${item.text}');
    }

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: '', // Add default email if needed
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body.toString())}',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email app')),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checklist Logged Locally')),
    );
    _loadData(); // Reset & Reload inspectors
    _inspectorController.clear();
  }

  Future<void> _exitApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit the program?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (kIsWeb) {
        SystemNavigator.pop();
      } else {
        exit(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Inspection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _exitApp,
            tooltip: 'Exit App',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownMenu<String>(
              controller: _inspectorController,
              label: const Text('Inspector Name'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: _inspectors.map((name) {
                return DropdownMenuEntry<String>(value: name, label: name);
              }).toList(),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Check for',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      textBaseline: TextBaseline.alphabetic,
                    ),
              ),
            ),
            ..._items.asMap().entries.map((entry) {
              int idx = entry.key;
              ChecklistItem item = entry.value;
              return CheckboxListTile(
                title: Text(item.text),
                value: item.isChecked,
                onChanged: (val) {
                  setState(() => _items[idx].isChecked = val ?? false);
                },
              );
            }).toList(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveAndEmail,
              child: const Text('Log It & Email'),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _storage = StorageService();
  List<ChecklistEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await _storage.getEntries();
    setState(() => _entries = entries);
  }

  Future<void> _deleteEntry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this inspection report?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.deleteEntry(id);
      _loadEntries();
    }
  }

  Future<void> _emailEntry(ChecklistEntry entry) async {
    final String dateStr = DateFormat('yyyy-MM-dd').format(entry.date);
    final String subject = 'Mariners Checklist Log - $dateStr - ${entry.inspectorName}';
    final StringBuffer body = StringBuffer();
    body.writeln('Inspection Date: $dateStr');
    body.writeln('Inspector: ${entry.inspectorName}');
    body.writeln('\nChecklist Items:');
    for (var item in entry.items) {
      body.writeln('${item.isChecked ? "[X]" : "[ ]"} ${item.text}');
    }

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: '',
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body.toString())}',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Exit App'),
                  content: const Text('Are you sure you want to exit the program?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                if (kIsWeb) {
                  SystemNavigator.pop();
                } else {
                  exit(0);
                }
              }
            },
            tooltip: 'Exit App',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return ExpansionTile(
            title: Text(DateFormat('MMMM d, yyyy').format(entry.date)),
            subtitle: Text('Inspector: ${entry.inspectorName}'),
            children: [
              ...entry.items.asMap().entries.map((itemEntry) {
                int itemIdx = itemEntry.key;
                ChecklistItem item = itemEntry.value;
                return CheckboxListTile(
                  title: Text(item.text),
                  value: item.isChecked,
                  onChanged: (val) async {
                    setState(() {
                      entry.items[itemIdx].isChecked = val ?? false;
                    });
                    await _storage.updateEntry(entry);
                  },
                );
              }).toList(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _deleteEntry(entry.id),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _emailEntry(entry),
                      icon: const Icon(Icons.email),
                      label: const Text('Resend Email'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ManageQuestionsPage extends StatefulWidget {
  const ManageQuestionsPage({super.key});

  @override
  State<ManageQuestionsPage> createState() => _ManageQuestionsPageState();
}

class _ManageQuestionsPageState extends State<ManageQuestionsPage> {
  final _storage = StorageService();
  List<ChecklistItem> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await _storage.getQuestions();
    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  Future<void> _addQuestion() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Question'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Enter question')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newQuestion = ChecklistItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  text: controller.text,
                );
                _questions.add(newQuestion);
                await _storage.saveQuestions(_questions);
                setState(() {});
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editQuestion(int index) async {
    final controller = TextEditingController(text: _questions[index].text);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Question'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                _questions[index].text = controller.text;
                await _storage.saveQuestions(_questions);
                setState(() {});
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () async {
              _questions.removeAt(index);
              await _storage.saveQuestions(_questions);
              setState(() {});
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Questions'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addQuestion),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Exit App'),
                  content: const Text('Are you sure you want to exit the program?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                if (kIsWeb) {
                  SystemNavigator.pop();
                } else {
                  exit(0);
                }
              }
            },
            tooltip: 'Exit App',
          ),
        ],
      ),
      body: ReorderableListView(
        onReorder: (oldIndex, newIndex) async {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _questions.removeAt(oldIndex);
            _questions.insert(newIndex, item);
          });
          await _storage.saveQuestions(_questions);
        },
        children: _questions.asMap().entries.map((entry) {
          int idx = entry.key;
          ChecklistItem q = entry.value;
          return ListTile(
            key: ValueKey(q.id),
            title: Text(q.text),
            trailing: const Icon(Icons.drag_handle),
            onTap: () => _editQuestion(idx),
          );
        }).toList(),
      ),
    );
  }
}
