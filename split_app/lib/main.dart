import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(home: CrudApp(), debugShowCheckedModeBanner: false));
}

class CrudApp extends StatefulWidget {
  @override
  _CrudAppState createState() => _CrudAppState();
}

class _CrudAppState extends State<CrudApp> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final CollectionReference students = FirebaseFirestore.instance.collection('students');

  Future<void> addStudent() async {
    await students.add({
      'name': nameController.text.trim(),
      'age': int.tryParse(ageController.text.trim()) ?? 0,
    });
    nameController.clear();
    ageController.clear();
  }

  Future<void> updateStudent(String id, String name, int age) async {
    await students.doc(id).update({'name': name, 'age': age});
  }

  Future<void> deleteStudent(String id) async {
    await students.doc(id).delete();
  }

  void showEditDialog(DocumentSnapshot doc) {
    final editName = TextEditingController(text: doc['name']);
    final editAge = TextEditingController(text: doc['age'].toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Update Student"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: editName, decoration: InputDecoration(labelText: "Name")),
            TextField(controller: editAge, decoration: InputDecoration(labelText: "Age"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              updateStudent(doc.id, editName.text.trim(), int.tryParse(editAge.text.trim()) ?? 0);
              Navigator.pop(context);
            },
            child: Text("Update"),
          )
        ],
      ),
    );
  }

  Widget studentForm() {
    return Column(
      children: [
        TextField(controller: nameController, decoration: InputDecoration(labelText: "Name")),
        SizedBox(height: 10),
        TextField(
          controller: ageController,
          decoration: InputDecoration(labelText: "Age"),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 10),
        ElevatedButton(onPressed: addStudent, child: Text("Add Student")),
        Divider(),
      ],
    );
  }

  Widget studentList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: students.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              return ListTile(
                title: Text(doc['name']),
                subtitle: Text("Age: ${doc['age']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: Icon(Icons.edit), onPressed: () => showEditDialog(doc)),
                    IconButton(icon: Icon(Icons.delete), onPressed: () => deleteStudent(doc.id)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Firestore CRUD")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [studentForm(), studentList()]),
      ),
    );
  }
}
