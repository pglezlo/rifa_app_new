import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'reimpresion_ticket.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: RifaHome());
  }
}

class RifaHome extends StatefulWidget {
  const RifaHome({super.key});

  @override
  State<RifaHome> createState() => _RifaHomeState();
}

class _RifaHomeState extends State<RifaHome> {
  final String baseUrl = "https://www.macfara.com/api";
  final TextEditingController nombrecontroller = TextEditingController();
  final TextEditingController telefonocontroller = TextEditingController();
  final TextEditingController codigocontroller = TextEditingController();
  int? idVendedor;
  String nombreCliente = "";
  String telefonoCliente = "";
  bool pago = false;
  bool cargando = false;
  String codigoVendedor = "";
  bool vendedorValido = false;
  bool _mostrarCodigo = false;
  int? numero; // Para guardar el número del boleto vendido

  void mostrarMensaje(String msg) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.info, color: Colors.blue, size: 28),
              SizedBox(width: 10),
              Text("Aviso"),
            ],
          ),
          content: Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        );
      },
    );

    // Se cierra automáticamente después de 5 segundos
    Future.delayed(Duration(seconds: 5), () {
      if (!mounted) return; // Verifica que el widget siga activo
      Navigator.of(context, rootNavigator: true).pop();
    });
  }

  Future<void> validarVendedor() async {
    final uri = Uri.parse("$baseUrl/validar_vendedor.php");
    try {
      final resp = await http.post(uri, body: {"codigo": codigoVendedor});
      final data = jsonDecode(resp.body);

      if (data["success"] == true) {
        setState(() {
          idVendedor = int.tryParse(data["id_vendedor"].toString());
          vendedorValido = true;
        });
        mostrarMensaje("Bienvenido ${data["nombre"]}");
      } else {
        mostrarMensaje(data["mensaje"]);
        setState(() => vendedorValido = false);
      }
    } catch (e) {
      mostrarMensaje("Error de conexión");
    }
  }

  Future<void> venderBoleto() async {
    if (!vendedorValido || idVendedor == null) return;

    final nombre = nombrecontroller.text.trim();
    final telefono = telefonocontroller.text.trim();

    if (nombre.isEmpty || telefono.isEmpty) {
      mostrarMensaje("Completa todos los campos");
      return;
    }

    setState(() => cargando = true);

    try {
      final uri = Uri.parse("$baseUrl/vender_boleto.php");
      final resp = await http.post(
        uri,
        body: {
          "nombre": nombreCliente,
          "telefono": telefonoCliente,
          "pago": (pago ? 1 : 0).toString(),
          "id_vendedor": idVendedor.toString(),
        },
      );

      final data = jsonDecode(resp.body);

      if (!mounted) return; // evita errores si el widget se destruyó

      setState(() => cargando = false);

      if (data["success"] == true) {
        final numero = data["numero"].toString();
        final precio = data["precio"].toString();

        mostrarMensaje("Boleto $numero vendido en \$$precio");

        await generarTicketPDF(
          numero: numero,
          nombreCliente: nombrecontroller.text,
          telefonoCliente: telefonocontroller.text,
          precio: double.parse(precio),
          pago: pago,
          idVendedor: idVendedor.toString(),
        );
        nombrecontroller.clear();
        telefonocontroller.clear();
        setState(() {
          pago = false;
        });
      } else {
        mostrarMensaje(data["mensaje"] ?? "Sin boletos disponibles");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => cargando = false);
      mostrarMensaje("Error de conexión 33");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[400], // fondo uniforme
      appBar: AppBar(
        title: Text("Rifa BMW 535i GT 2016"),
        backgroundColor: Colors.blueAccent, // color uniforme de AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!vendedorValido) ...[
                TextField(
                  controller: codigocontroller,
                  decoration: InputDecoration(
                    labelText: "Código del vendedor",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _mostrarCodigo
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _mostrarCodigo = !_mostrarCodigo;
                        });
                      },
                    ),
                  ),
                  obscureText: !_mostrarCodigo,
                  onChanged: (v) => codigoVendedor = v,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, // color uniforme
                      foregroundColor: Colors.black),
                  onPressed: validarVendedor,
                  child: Text(
                    "Validar Vendedor",
                    style: TextStyle(
                        fontSize: 18, // tamaño del texto
                        fontWeight: FontWeight.bold // negrita
                        ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (vendedorValido) ...[
                TextField(
                  controller: nombrecontroller,
                  decoration: const InputDecoration(
                    labelText: "Nombre del cliente *",
                  ),
                  onChanged: (v) => nombreCliente = v,
                ),
                TextField(
                  controller: telefonocontroller,
                  decoration: const InputDecoration(
                    labelText: "Teléfono del cliente *",
                  ),
                  onChanged: (v) => telefonoCliente = v,
                  keyboardType: TextInputType.phone,
                ),
                CheckboxListTile(
                  title: const Text("Boleto pagado"),
                  value: pago,
                  onChanged: (valor) => setState(() => pago = valor!),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // color uniforme
                    foregroundColor: Colors.black,
                  ),
                  onPressed: cargando ? null : venderBoleto,
                  child: cargando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Vender Boleto",
                          style: TextStyle(
                            fontSize: 18, // tamaño del texto
                            fontWeight: FontWeight.bold, // negrita
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // color uniforme
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VideoArticuloPage(
                          videoUrl:
                              "https://www.macfara.com/Videos/BMW_2016.mp4",
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "Ver Video del BMW",
                    style: TextStyle(
                        fontSize: 18, // tamaño del texto
                        fontWeight: FontWeight.bold // negrita
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // color uniforme
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DatosCompraPage(),
                      ),
                    );
                  },
                  child: Text(
                    "Informacion Bancaria",
                    style: TextStyle(
                        fontSize: 18, // tamaño del texto
                        fontWeight: FontWeight.bold // negrita
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // color uniforme
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistorialPage(
                          idVendedor: idVendedor!,
                          baseUrl: baseUrl,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "Historial Venta",
                    style: TextStyle(
                        fontSize: 18, // tamaño del texto
                        fontWeight: FontWeight.bold // negrita
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // color uniforme
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReimpresionTicket(
                          baseUrl: baseUrl,
                          idVendedor: idVendedor.toString(),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "Reimprimir Ticket",
                    style: TextStyle(
                        fontSize: 18, // tamaño del texto
                        fontWeight: FontWeight.bold // negrita
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // color uniforme
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  child: Text(
                    "Cerrar Aplicacion",
                    style: TextStyle(
                        fontSize: 18, // tamaño del texto
                        fontWeight: FontWeight.bold // negrita
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

//Generar y Compartir Boleto
Future<void> generarTicketPDF({
  required String numero,
  required String nombreCliente,
  required String telefonoCliente,
  required double precio,
  required bool pago,
  required String idVendedor,
}) async {
  final fontEmoji =
      pw.Font.ttf(await rootBundle.load("assets/fonts/Symbola.ttf"));
  final pdf = pw.Document();
  final fecha = DateTime.now();
  final formatoFecha = "${fecha.day}/${fecha.month}/${fecha.year}";

  pdf.addPage(
    pw.Page(
      // pageFormat: PdfPageFormat.roll80,
      pageFormat: PdfPageFormat(310, 250),
      build: (pw.Context context) => pw.Center(
        child: pw.Container(
          width: 300,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  "🎟️ Comprobante de Boleto",
                  style: pw.TextStyle(
                      font: fontEmoji,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("🎟️ Boleto #: $numero",
                  style: pw.TextStyle(font: fontEmoji, fontSize: 14)),
              pw.Text("👤 Cliente: $nombreCliente",
                  style: pw.TextStyle(font: fontEmoji, fontSize: 14)),
              pw.Text("📞 Telefono: $telefonoCliente",
                  style: pw.TextStyle(font: fontEmoji, fontSize: 14)),
              pw.Text("💲 Precio: \$${precio.toStringAsFixed(2)}",
                  style: pw.TextStyle(font: fontEmoji, fontSize: 14)),
              pw.Text("💰 Pagado: ${pago ? 'Si' : 'No'}",
                  style: pw.TextStyle(font: fontEmoji, fontSize: 14)),
              pw.Text("🧑‍💼 Vendedor: $idVendedor",
                  style: pw.TextStyle(font: fontEmoji, fontSize: 14)),
              pw.Text("📅 Fecha: $formatoFecha",
                  style: pw.TextStyle(font: fontEmoji, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Center(
                  child: pw.Text(
                      "Suerte con su compra, --Recuerde que para participar en el sorteo el boleto debera estar pagado--")),
            ],
          ),
        ),
      ),
    ),
  );

  final output = await getTemporaryDirectory();
  final file = File("${output.path}/ticket_$numero.pdf");
  await file.writeAsBytes(await pdf.save());

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      text: 'Ticket de venta #$numero',
    ),
  );
}

// Pantalla de video
class VideoArticuloPage extends StatelessWidget {
  final String videoUrl;
  const VideoArticuloPage({super.key, required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[400],
      appBar: AppBar(
        title: Text("Video del BMW 535i GT"),
        backgroundColor: Colors.blueAccent, // color uniforme de AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // color uniforme
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(videoUrl))) {
                  await launchUrl(
                    Uri.parse(videoUrl),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!context.mounted) return; // evita el warning
                } else {
                  if (!context.mounted) return; // evita el warning
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No se pudo abrir el video")),
                  );
                }
              },
              child: const Text("Ver video del artículo"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // color uniforme
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Regresar al inicio"),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla de datos de compra
class DatosCompraPage extends StatelessWidget {
  const DatosCompraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[400],
      appBar: AppBar(
        title: Text("Datos Bancarios para Deposito"),
        backgroundColor: Colors.blueAccent, // color uniforme de AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Datos para proceso de pago:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              "💳 OPCIÓN 1",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text("Banco: Banamex",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Tarjeta: 5204 1674 2340 3591",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Titular: José Marcos González López",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
              "💳 OPCIÓN 2",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text("Banco: Bancomer",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Tarjeta: 4152 3142 9524 4985",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Titular: Angélica María Córdova Virgen",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // color uniforme
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Regresar al inicio"),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla de historial de ventas
class HistorialPage extends StatefulWidget {
  final int idVendedor;
  final String baseUrl;
  const HistorialPage({
    super.key,
    required this.idVendedor,
    required this.baseUrl,
  });

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  List historial = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  Future<void> cargarHistorial() async {
    final uri = Uri.parse(
      "${widget.baseUrl}/historial_boletos.php?id_vendedor=${widget.idVendedor}",
    );
    try {
      final resp = await http.get(uri);
      final data = jsonDecode(resp.body);
      if (!mounted) return; // evita usar context si el widget ya no existe
      setState(() {
        historial = data;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return; // evita usar context si el widget ya no existe
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al cargar historial")),
      );
    }
  }

  String fechaFormateada(String fechaRaw) {
    try {
      final fecha = DateTime.parse(fechaRaw);
      return DateFormat('MM-dd-yy').format(fecha);
    } catch (e) {
      return fechaRaw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[400],
      appBar: AppBar(
        title: Text("Historial de Ventas"),
        backgroundColor: Colors.blueAccent, // color uniforme de AppBar
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : historial.isEmpty
              ? const Center(child: Text("No hay boletos vendidos"))
              : ListView.builder(
                  itemCount: historial.length,
                  itemBuilder: (context, i) {
                    final item = historial[i];
                    return ListTile(
                      title: Text(
                        "Boleto #${item["numero"]}",
                        style: TextStyle(
                          fontSize: 20, // tamaño más grande
                          fontWeight: FontWeight.bold, // negrita
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("👤Cliente: ${item["nombre_cliente"]}",
                              style: const TextStyle(fontSize: 16)),
                          Text("💲Precio: \$${item["precio"]}",
                              style: const TextStyle(fontSize: 18)),
                          Text("💰Pagado: ${item["pagado"] == 1 ? '✅' : '❌'}",
                              style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                      trailing: Text(
                        fechaFormateada(item["fecha_venta"] != null &&
                                item["fecha_venta"] != ""
                            ? item["fecha_venta"]
                            : "Sin fecha"),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(10),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent, // color uniforme
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Regresar al inicio"),
        ),
      ),
    );
  }
}
