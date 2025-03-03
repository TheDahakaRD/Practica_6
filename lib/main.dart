import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

/// Widget principal de la aplicación
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conversor de Monedas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainScreen(),
    );
  }
}

/// Pantalla principal que utiliza un TabBar para navegar entre Conversión y Historia
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  Map<String, String> currencies = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchCurrencies();
  }

  /// Obtiene la lista de monedas desde la API
  Future<void> fetchCurrencies() async {
    final response =
        await http.get(Uri.parse('https://api.frankfurter.app/currencies'));
    if (response.statusCode == 200) {
      setState(() {
        currencies = Map<String, String>.from(json.decode(response.body));
      });
    } else {
      // Manejo de error simple
      print('Error al cargar las monedas.');
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conversor de Monedas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Conversión'),
            Tab(text: 'Historia'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ConversionScreen(currencies: currencies),
          HistoryScreen(currencies: currencies),
        ],
      ),
    );
  }
}

/// Pantalla de Conversión
class ConversionScreen extends StatefulWidget {
  final Map<String, String> currencies;
  ConversionScreen({required this.currencies});

  @override
  _ConversionScreenState createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController amountController = TextEditingController();
  DateTime? selectedDate;
  String? fromCurrency;
  String? toCurrency;
  String result = '';

  @override
  void initState() {
    super.initState();
    if (widget.currencies.isNotEmpty) {
      // Valores por defecto
      fromCurrency = 'EUR';
      toCurrency = 'USD';
    }
  }

  /// Muestra un selector de fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1999), // fecha mínima de ejemplo
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate)
      setState(() {
        selectedDate = picked;
      });
  }

  /// Realiza la conversión llamando a la API de Frankfurter
  Future<void> convertCurrency() async {
    if (!_formKey.currentState!.validate()) return;
    double amount = double.tryParse(amountController.text) ?? 0;
    if (fromCurrency == null || toCurrency == null) return;

    String datePart = '';
    if (selectedDate != null) {
      // Formatear la fecha a yyyy-MM-dd
      datePart =
          '${selectedDate!.year.toString().padLeft(4, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
    }
    String url;
    if (datePart.isNotEmpty) {
      url =
          'https://api.frankfurter.app/$datePart?amount=$amount&from=$fromCurrency&to=$toCurrency';
    } else {
      url =
          'https://api.frankfurter.app/latest?amount=$amount&from=$fromCurrency&to=$toCurrency';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          result =
              '$amount $fromCurrency = ${data['rates'][toCurrency]} $toCurrency (Fecha: ${data['date']})';
        });
      } else {
        setState(() {
          result = 'Error en la conversión.';
        });
      }
    } catch (e) {
      setState(() {
        result = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: widget.currencies.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: InputDecoration(labelText: 'Cantidad'),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa una cantidad';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: fromCurrency,
                    decoration: InputDecoration(labelText: 'Moneda Base'),
                    items: widget.currencies.keys.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text('$code - ${widget.currencies[code]}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        fromCurrency = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: toCurrency,
                    decoration: InputDecoration(labelText: 'Moneda Destino'),
                    items: widget.currencies.keys.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text('$code - ${widget.currencies[code]}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        toCurrency = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(selectedDate == null
                            ? 'Selecciona una fecha (opcional)'
                            : 'Fecha: ${selectedDate!.toLocal()}'
                                .split(' ')[0]),
                      ),
                      ElevatedButton(
                        onPressed: () => _selectDate(context),
                        child: Text('Seleccionar Fecha'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: convertCurrency,
                    child: Text('Convertir'),
                  ),
                  SizedBox(height: 16),
                  Text(result, style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
    );
  }
}

/// Pantalla de Historia de Tasas de Cambio
class HistoryScreen extends StatefulWidget {
  final Map<String, String> currencies;
  HistoryScreen({required this.currencies});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? baseCurrency;
  Map<String, dynamic> rates = {};

  @override
  void initState() {
    super.initState();
    if (widget.currencies.isNotEmpty) {
      baseCurrency = 'EUR';
      fetchRates();
    }
  }

  /// Obtiene las tasas de cambio para la moneda base seleccionada
  Future<void> fetchRates() async {
    if (baseCurrency == null) return;
    String url = 'https://api.frankfurter.app/latest?from=$baseCurrency';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          rates = data['rates'];
        });
      } else {
        setState(() {
          rates = {};
        });
      }
    } catch (e) {
      setState(() {
        rates = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: widget.currencies.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: baseCurrency,
                  decoration: InputDecoration(labelText: 'Moneda Base'),
                  items: widget.currencies.keys.map((code) {
                    return DropdownMenuItem(
                      value: code,
                      child: Text('$code - ${widget.currencies[code]}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      baseCurrency = value;
                    });
                    fetchRates();
                  },
                ),
                SizedBox(height: 16),
                Expanded(
                  child: rates.isEmpty
                      ? Center(child: CircularProgressIndicator())
                      : ListView(
                          children: rates.keys.map((currency) {
                            return ListTile(
                              title: Text('$baseCurrency → $currency'),
                              trailing: Text(rates[currency].toString()),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}
