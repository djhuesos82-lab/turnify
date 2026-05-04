// 🔥 IMPORTS COMPLETOS
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:table_calendar/table_calendar.dart';

final notifications = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCIhdwIuX3D9HAzpS9PE4fMKzyo8l6-98s",
        appId: "1:826105899775:android:60ebde0a919778788abaca",
        messagingSenderId: "826105899775",
        projectId: "turnify-uvm2026",
        storageBucket: "turnify-uvm2026.firebasestorage.app",
      ),
    );
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(const InitializationSettings(android: android));
    runApp(const MyApp());
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Error de inicio:\n$e")))));
  }
}

// 🔔 SISTEMA DE NOTIFICACIONES
Future<void> programarNotificacion(DateTime fecha, String id) async {
  final recordatorio = fecha.subtract(const Duration(minutes: 10));
  if (recordatorio.isBefore(DateTime.now())) return;
  await notifications.cancel(id.hashCode);
  await notifications.zonedSchedule(
    id.hashCode,
    'Turnify: Recordatorio',
    'Tienes un turno en 10 minutos',
    tz.TZDateTime.from(recordatorio, tz.local),
    const NotificationDetails(
        android: AndroidNotificationDetails('turnos', 'Alertas de Turnos',
            importance: Importance.max, priority: Priority.high)),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
  );
}

// 📂 LOGICA DE SUBIDA A STORAGE
Future<void> subirArchivo(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    final file = result.files.first;
    final ref = FirebaseStorage.instance.ref().child('docs/${DateTime.now().millisecondsSinceEpoch}_${file.name}');

    if (file.bytes != null) {
      await ref.putData(file.bytes!);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('documentos').add({
        'nombre': file.name,
        'url': url,
        'fecha': DateTime.now(),
        'userId': FirebaseAuth.instance.currentUser!.uid,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Documento cargado exitosamente")));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir archivo: $e")));
  }
}

// ================= MODELO DE DATOS =================
class Turno {
  final String id;
  final String descripcion;
  final DateTime fecha;

  Turno({required this.id, required this.descripcion, required this.fecha});

  factory Turno.fromMap(String id, Map<String, dynamic> data) {
    return Turno(
      id: id,
      descripcion: data['descripcion'] ?? 'Sin descripción',
      fecha: (data['fecha'] as Timestamp).toDate(),
    );
  }
}

// ================= ESTRUCTURA APP =================
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: const Color(0xFFE3F2FD),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// ================= CONTROL DE ACCESO (AUTH) =================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return const HomeScreen();
        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final emailCont = TextEditingController();
  final passCont = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Card(
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(children: [
                const Icon(Icons.calendar_today, size: 50, color: Colors.blue),
                const SizedBox(height: 10),
                const Text("Turnify", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: emailCont, decoration: const InputDecoration(labelText: "Correo")),
                TextField(controller: passCont, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña")),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      if (isLogin) {
                        await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailCont.text.trim(), password: passCont.text.trim());
                      } else {
                        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCont.text.trim(), password: passCont.text.trim());
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  child: Text(isLogin ? "Entrar" : "Registrarme"),
                ),
                TextButton(
                  onPressed: () async {
                    if (emailCont.text.isEmpty) return;
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: emailCont.text);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Correo de recuperación enviado")));
                  },
                  child: const Text("Olvidé mi contraseña"),
                ),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(isLogin ? "¿No tienes cuenta? Crea una" : "¿Ya tienes cuenta? Inicia sesión"),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= NAVEGACIÓN PRINCIPAL =================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  int i = 0;
  final screens = [
    const TurnosScreen(),
    const CalendarioScreen(),
    const VerificacionDocsScreen(),
    const PerfilScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[i],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: i,
        onTap: (v) => setState(() => i = v),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Turnos"),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Agenda"),
          BottomNavigationBarItem(icon: Icon(Icons.verified_user), label: "Verificar"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
      ),
    );
  }
}

// ================= GESTIÓN DE TURNOS (CRUD) =================
class TurnosScreen extends StatelessWidget {
  const TurnosScreen({super.key});

  void form(BuildContext context, {Turno? turno}) {
    final descCont = TextEditingController(text: turno?.descripcion);
    DateTime? f = turno?.fecha;
    TimeOfDay? h = turno != null ? TimeOfDay.fromDateTime(turno.fecha) : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(turno == null ? "Nuevo Turno" : "Editar Turno"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: descCont, decoration: const InputDecoration(hintText: "Descripción")),
            ListTile(
              title: Text(f == null ? "Fecha" : DateFormat('dd/MM/yyyy').format(f!)),
              onTap: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2100), initialDate: f ?? DateTime.now());
                if (d != null) setState(() => f = d);
              },
            ),
            ListTile(
              title: Text(h == null ? "Hora" : h!.format(context)),
              onTap: () async {
                final hr = await showTimePicker(context: context, initialTime: h ?? TimeOfDay.now());
                if (hr != null) setState(() => h = hr);
              },
            ),
          ]),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (f == null || h == null) return;
                final fFinal = DateTime(f!.year, f!.month, f!.day, h!.hour, h!.minute);
                final data = {'descripcion': descCont.text, 'fecha': fFinal, 'userId': FirebaseAuth.instance.currentUser!.uid};

                if (turno == null) {
                  final doc = await FirebaseFirestore.instance.collection('turnos').add(data);
                  await programarNotificacion(fFinal, doc.id);
                } else {
                  await FirebaseFirestore.instance.collection('turnos').doc(turno.id).update(data);
                  await programarNotificacion(fFinal, turno.id);
                }
                Navigator.pop(context);
              },
              child: const Text("Guardar"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Turnos")),
      floatingActionButton: FloatingActionButton(onPressed: () => form(context), child: const Icon(Icons.add)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('turnos').where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid).orderBy('fecha').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final t = Turno.fromMap(doc.id, doc.data() as Map<String, dynamic>);
              return ListTile(
                title: Text(t.descripcion),
                subtitle: Text(DateFormat('dd/MM HH:mm').format(t.fecha)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => form(context, turno: t)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('turnos').doc(t.id).delete()),
                ]),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ================= CALENDARIO =================
class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});
  @override
  State<CalendarioScreen> createState() => _CalState();
}

class _CalState extends State<CalendarioScreen> {
  DateTime selected = DateTime.now();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agenda Mensual")),
      body: Column(children: [
        TableCalendar(
          focusedDay: selected, firstDay: DateTime(2020), lastDay: DateTime(2100),
          selectedDayPredicate: (d) => isSameDay(d, selected),
          onDaySelected: (d, _) => setState(() => selected = d),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('turnos').where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final filtrados = snapshot.data!.docs.where((d) => isSameDay((d['fecha'] as Timestamp).toDate(), selected)).toList();
              return ListView(
                children: filtrados.map((doc) => ListTile(title: Text(doc['descripcion']), subtitle: Text(DateFormat('HH:mm').format((doc['fecha'] as Timestamp).toDate())))).toList(),
              );
            },
          ),
        )
      ]),
    );
  }
}

// ================= VERIFICACIÓN DE DOCUMENTOS =================
class VerificacionDocsScreen extends StatelessWidget {
  const VerificacionDocsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Estado de Documentos")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('documentos').where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No hay documentos subidos."));
          return ListView(
            padding: const EdgeInsets.all(15),
            children: snapshot.data!.docs.map((doc) => Card(
              child: ListTile(
                leading: const Icon(Icons.file_present, color: Colors.blue),
                title: Text(doc['nombre']),
                subtitle: const Text("Estado: Recibido correctamente"),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            )).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => subirArchivo(context), label: const Text("Subir"), icon: const Icon(Icons.upload)),
    );
  }
}

// ================= PERFIL =================
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Perfil")),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.person, size: 80),
          Text(FirebaseAuth.instance.currentUser?.email ?? ""),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text("Cerrar Sesión")),
        ]),
      ),
    );
  }
}