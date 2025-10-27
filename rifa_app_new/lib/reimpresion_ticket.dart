import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // importa tu función generarTicketPDF

class ReimpresionTicket extends StatefulWidget {
  final String baseUrl;
  final String idVendedor; // <- Agregar esto
  const ReimpresionTicket({
    super.key,
    required this.baseUrl,
    required this.idVendedor,
  });

  @override
  State<ReimpresionTicket> createState() => _ReimpresionTicketState();
}

class _ReimpresionTicketState extends State<ReimpresionTicket> {
  final TextEditingController _numeroController = TextEditingController();
  Map<String, dynamic>? boleto;
  bool cargando = false;

  Future<void> buscarBoleto() async {
    final numero = _numeroController.text.trim();
    if (numero.isEmpty) {
      mostrarMensaje("Ingresa un número de boleto");
      return;
    }

    setState(() => cargando = true);
    //print(numero); // Ejemplo de uso
    try {
      final url = Uri.parse("${widget.baseUrl}/consultar_boleto.php");
      final respuesta = await http.post(url, body: {
        "numero": numero,
        "id_vendedor": widget.idVendedor,
      });

      if (respuesta.statusCode == 200) {
        final data = json.decode(respuesta.body);
        if (data["success"] == true) {
          setState(() => boleto = data["boleto"]);
        } else {
          mostrarMensaje("No se encontró el boleto");
        }
      } else {
        mostrarMensaje("Error en el servidor");
      }
    } catch (e) {
      mostrarMensaje("Error de conexión");
    } finally {
      setState(() => cargando = false);
    }
  }

  Future<void> reimprimirTicket() async {
    if (boleto == null) {
      mostrarMensaje("Primero busca un boleto válido");
      return;
    }

    await generarTicketPDF(
      numero: boleto!["numero"].toString(),
      nombreCliente: boleto!["nombre_cliente"],
      telefonoCliente: boleto!["telefono_cliente"],
      precio: double.tryParse(boleto!["precio"].toString()) ?? 0,
      pago: boleto!["pagado"].toString() == "1",
      idVendedor: boleto!["id_vendedor"].toString(),
    );
  }

  void mostrarMensaje(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[400], // fondo uniforme
      appBar: AppBar(
        title: const Text("Reimpresión de Ticket"),
        backgroundColor: Colors.blueAccent, // color uniforme de AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _numeroController,
              decoration: const InputDecoration(
                labelText: "Número de boleto",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, // color uniforme
                  foregroundColor: Colors.black),
              onPressed: buscarBoleto,
              child: const Text("Buscar"),
            ),
            const SizedBox(height: 20),
            if (cargando)
              const CircularProgressIndicator()
            else if (boleto != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("🎟️ Boleto #${boleto!["numero"]}",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("👤 Cliente: ${boleto!["nombre_cliente"]}"),
                  Text("📞 Teléfono: ${boleto!["telefono_cliente"]}"),
                  Text("💲 Precio: \$${boleto!["precio"]}"),
                  Text("💰Pagado: ${boleto!["pagado"] == 1 ? "Sí" : "No"}"),
                  Text("🧑‍💼 Vendedor: ${boleto!["id_vendedor"]}"),
                  Text("📅 Fecha: ${boleto!["fecha_venta"]}"),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Generar y Compartir Ticket"),
                    onPressed: reimprimirTicket,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
