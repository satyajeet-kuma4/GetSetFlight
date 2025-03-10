import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  DateTime? selectedDate;
  List<dynamic> flights = [];
  bool isLoading = false;
  bool showNonStopOnly = false;

  void pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> searchFlights() async {
    if (fromController.text.isEmpty ||
        toController.text.isEmpty ||
        selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all the fields')));
      return;
    }

    setState(() {
      isLoading = true;
      flights = [];
    });

    try {
      final String from = fromController.text.trim();
      final String to = toController.text.trim();
      final String date = DateFormat('yyyy-MM-dd').format(selectedDate!);

      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/flights'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"source": from, "destination": to, "date": date}),
      );

      if (response.statusCode == 200) {
        List<dynamic> fetchedFlights = jsonDecode(response.body);

        setState(() {
          flights = fetchedFlights;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to fetch flights");
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('An error occurred')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> filteredFlights = showNonStopOnly
        ? flights.where((flight) => flight["stops"] == 0).toList()
        : flights;

    return Scaffold(
      appBar: AppBar(title: const Text('Flight Search')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: fromController,
              decoration: const InputDecoration(labelText: 'From City'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: toController,
              decoration: const InputDecoration(labelText: 'To City'),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Select Date',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                      : 'Choose a date',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: showNonStopOnly,
                  onChanged: (value) {
                    setState(() {
                      showNonStopOnly = value!;
                    });
                  },
                ),
                const Text("Show only non-stop flights"),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: searchFlights,
              child: const Text('Search Flights'),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredFlights.isEmpty
                      ? const Center(child: Text("No flights found"))
                      : ListView.builder(
                          itemCount: filteredFlights.length,
                          itemBuilder: (context, index) {
                            final flight = filteredFlights[index];

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Airline Name
                                    Text(
                                      flight["airline"] ?? "Unknown Airline",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Departure and Arrival Information
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            "Departure: ${flight["departure"]} (${flight["departure_city"]})"),
                                        Text(
                                            "Arrival: ${flight["arrival"]} (${flight["arrival_city"]})"),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Duration
                                    Center(
                                      child: Text(
                                        "Duration: ${flight["duration"] ?? "Unknown"}",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Price Information (Moved Below Departure & Arrival)
                                    Text(
                                      flight["price"] ?? "Unknown Price",
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
