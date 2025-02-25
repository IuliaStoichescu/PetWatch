import 'package:flutter/material.dart';

class PetCard extends StatelessWidget {
  final String petName;
  final String petImage;
  final String petSex;
  final String petWeight;

  const PetCard({
    super.key,
    required this.petName,
    required this.petImage,
    required this.petSex,
    required this.petWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: petImage.isNotEmpty
            ? CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(petImage),
              )
            : CircleAvatar(
                radius: 30,
                child: Icon(Icons.pets, size: 30),
              ),
        title: Text(petName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text("Sex: $petSex | Weight: $petWeight"),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: () {
          // You can navigate to pet details here if needed
        },
      ),
    );
  }
}
