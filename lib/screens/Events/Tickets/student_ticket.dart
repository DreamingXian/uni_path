import 'package:flutter/material.dart';

class StudentTicketScreen extends StatelessWidget {
  const StudentTicketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Tickets")),
      body: const Center(child: Text("Student Ticket Management will go here")),
    );
  }
}