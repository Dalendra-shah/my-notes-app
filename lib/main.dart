
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyNotesApp());
}

class MyNotesApp extends StatelessWidget {
  const MyNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Notes',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
      ),
      home: const NotesHomePage(),
    );
  }
}

class Note {
  String id;
  String title;
  String content;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key});

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  List<Note> notes = [];
  bool isLoading = true;

  final TextEditingController searchController =
      TextEditingController();

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNotes = prefs.getString('my_notes');

    if (savedNotes != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedNotes);
        notes = decoded.map((item) {
          return Note.fromJson(
            Map<String, dynamic>.from(item),
          );
        }).toList();
      } catch (_) {
        notes = [];
      }
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveNotes() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      notes.map((note) => note.toJson()).toList(),
    );

    await prefs.setString('my_notes', encoded);
  }

  List<Note> get filteredNotes {
    final query = searchQuery.toLowerCase();

    return notes.where((note) {
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> openNoteEditor({Note? note}) async {
    final titleController = TextEditingController(
      text: note?.title ?? '',
    );

    final contentController = TextEditingController(
      text: note?.content ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(note == null ? 'New Note' : 'Edit Note'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Note title',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization:
                        TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'Write your note...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 5,
                    maxLines: 10,
                    textCapitalization:
                        TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();

                if (title.isEmpty && content.isEmpty) {
                  return;
                }

                final now = DateTime.now();

                setState(() {
                  if (note == null) {
                    notes.add(
                      Note(
                        id: now.microsecondsSinceEpoch.toString(),
                        title: title.isEmpty ? 'Untitled' : title,
                        content: content,
                        updatedAt: now,
                      ),
                    );
                  } else {
                    note.title =
                        title.isEmpty ? 'Untitled' : title;
                    note.content = content;
                    note.updatedAt = now;
                  }
                });

                await saveNotes();

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    contentController.dispose();
  }

  Future<void> deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text(
          'Are you sure you want to delete this note?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        notes.removeWhere((item) => item.id == note.id);
      });

      await saveNotes();
    }
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();

    if (now.year == date.year &&
        now.month == date.month &&
        now.day == date.day) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotes = filteredNotes;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Notes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFFF8F7FC),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search your notes...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        'Your Notes',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text('${notes.length} notes'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: visibleNotes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  searchQuery.isEmpty
                                      ? Icons.note_alt_outlined
                                      : Icons.search_off,
                                  size: 65,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchQuery.isEmpty
                                      ? 'No notes yet'
                                      : 'No matching notes',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tap + to create your first note.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: visibleNotes.length,
                            itemBuilder: (context, index) {
                              final note = visibleNotes[index];

                              return Card(
                                color: Colors.white,
                                margin: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.all(14),
                                  title: Text(
                                    note.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding:
                                        const EdgeInsets.only(top: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          note.content.isEmpty
                                              ? 'No additional text'
                                              : note.content,
                                          maxLines: 3,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          formatDate(note.updatedAt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onTap: () =>
                                      openNoteEditor(note: note),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => deleteNote(note),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNoteEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }
}
