import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pet_watch/login_signin/myTextField.dart';
import 'package:pet_watch/login_signin/services/storage_service.dart';
import 'package:provider/provider.dart';

class AddPet extends StatefulWidget {
  const AddPet({super.key});

  @override
  State<AddPet> createState() => _AddPetState();
}

class _AddPetState extends State<AddPet> {
  //fields for pet profile
  final TextEditingController nameController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  final TextEditingController kilosController = TextEditingController();
  final TextEditingController customAnimalController = TextEditingController();
  String? selectedSex;
  String imageUrl = ""; 
  int kilos=0;
  String ?selectedAnimal;
  String? selectedBreed;
  DateTime? birthDate;

  @override
  void initState(){
    super.initState();
    fetchImages();
  }

  void savePetInfo(List<String> image) async{
     final User user = FirebaseAuth.instance.currentUser!;
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  DocumentReference userRef = firestore.collection("users").doc(user.uid);

  try {
    DocumentSnapshot userSnapshot = await userRef.get();
    if (!userSnapshot.exists) {
      await userRef.set({
        "uid": user.uid,
        "email": user.email,
        "createdAt": FieldValue.serverTimestamp(),
      });
    }

    DocumentReference petRef = await userRef.collection("pets").add({
      "timestamp": FieldValue.serverTimestamp(),
    });

    // 🔹 Ensure "about" text is correctly trimmed and saved
    await petRef.collection("pet_info").doc("details").set({
      "name": nameController.text.trim(),
      "sex": selectedSex ?? "Unknown",
      "imageUrl": image.isNotEmpty ? image.last : "",
      "about": aboutController.text.trim(), 
      "kilograms": "${kilosController.text.trim()} kg",
      "animalType": selectedAnimal =='Other'? customAnimalController.text.trim():selectedAnimal,
      "breed":selectedBreed?? "Unknown",
      "birthDate": birthDate?.toIso8601String()??"Not provided",
    });

    Navigator.pop(context,true); // Close the dialog after saving

    setState(() {
      nameController.clear();
      aboutController.clear();
      kilosController.clear();
      selectedSex = null;
      selectedAnimal=null;
      selectedBreed=null;
      birthDate=null;
      customAnimalController.clear();
    });

  } catch (e) {
    print("Error saving pet info: $e");
  }
  }


  Future<void> fetchImages() async{
    await Provider.of<StorageService>(context,listen: false).fetchImages();
  }
final minWidth = 500.0;
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Consumer<StorageService>(
      builder: (context,storageService,child){
        final List<String> imageUrls = storageService.imageURL;
    return Container(
         decoration: BoxDecoration(
            color: Color(0xFF6C4C57), 
            borderRadius: BorderRadius.circular(15), 
          ),
        child: ConstrainedBox(
           constraints: BoxConstraints(
                    maxWidth: max(screenWidth, minWidth),
                          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 10,width: 30,),
                    FittedBox(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20,),
                            Column(
                              children: [
                                Text("Let's create ",style: TextStyle(fontSize: 20,color: Colors.white),),
                                Text("your pet's profile!",style: TextStyle(fontSize: 20,color: Colors.white),),
                                Text("(Guide. Continue below ⬇️)",style: TextStyle(color: Colors.white))
                              ],
                            ),
                            Lottie.asset("assets/cat_play.json",width: 150,height: 150),
                          ],
                        ),
                    ),
                    Text("🔷Once your pet’s profile is ready, ",style: TextStyle(color: Colors.white)),
                    Text("you'll see a toggle switch next to it",style: TextStyle(color: Colors.white)),
                    SizedBox(height: 10,),
                    Divider(thickness: 0.5,color: const Color.fromARGB(255, 44, 44, 44),),
                    SizedBox(height: 10,),
                    Text("🔷Red Toggle: Your pet tracker is not ",style: TextStyle(color: Colors.white)),
                    Text("linked yet. Keep it like this until you",style: TextStyle(color: Colors.white)),
                    Text(" make sure to attach the tracking device ",style: TextStyle(color: Colors.white)),
                    Text("to your pet's collar.",style: TextStyle(color: Colors.white)),
                    Image.asset("assets/off.png",width: 150,height: 150,),
                    SizedBox(height: 10,),
                    Divider(thickness: 0.5,color: const Color.fromARGB(255, 44, 44, 44),),
                    SizedBox(height: 10,),
                    Text("🔷When you switch it to the Green Toggle that ",style: TextStyle(color: Colors.white)),
                    Text("means the device is successfully connected!",style: TextStyle(color: Colors.white)),
                    Text(" Now, you’re all set to track your pet’s location",style: TextStyle(color: Colors.white)),
                    Text(" in real-time",style: TextStyle(color: Colors.white)),
                    Image.asset("assets/on.png",width: 150,height: 150,),
                    SizedBox(height: 30,),
                    Text("Pet Profile",style: TextStyle(color: Colors.white,fontSize: 30,decoration: TextDecoration.underline,decorationColor: const Color.fromARGB(255, 255, 255, 255),),),
                    SizedBox(height: 30,),
                    Mytextfield(controller: nameController,hintText: "PetName",prefixIcon: Icon(Icons.pets,color: Colors.white,),obscureText: false,),
                    SizedBox(height: 20,),
                    SizedBox(
                      width: 265, 
                      child: DropdownButtonFormField<String>(
                        value: selectedSex,
                        items: ["Male", "Female"].map((String sex) {
                          return DropdownMenuItem(
                            value: sex,
                            child: Text(
                              sex,
                              style: TextStyle(color: Colors.white), 
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSex = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: "Gender",
                          labelStyle: TextStyle(color: Colors.white), 
                          filled: true,
                          fillColor: const Color.fromARGB(98, 255, 255, 255), 
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), 
                            borderSide: BorderSide.none, 
                          ),
                        ),
                        dropdownColor: Colors.grey[700], 
                      ),
                    ),
                    SizedBox(height: 30,),
                    SizedBox(
                      width: 265, 
                      child: DropdownButtonFormField<String>(
                        value: selectedAnimal,
                        items: ['🐶 Dog','🐱 Cat','Other'].map((animal) => 
                        DropdownMenuItem(
                          
                          value: animal,child: Text(animal,style: TextStyle(color: Colors.white),))).toList(),
                        onChanged: (value)=>setState(() {
                          selectedAnimal=value;
                          selectedBreed = null;
                        }),
                        decoration: InputDecoration(
                          labelText: "Animal Type",
                           labelStyle: TextStyle(color: Colors.white), 
                          filled: true,
                          fillColor: const Color.fromARGB(98, 255, 255, 255), 
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), 
                            borderSide: BorderSide.none, 
                          ),
                          ),
                          dropdownColor: Colors.grey[700], 
                      ),
                    ),
                    SizedBox(height: 30,),
                    if (selectedAnimal == '🐶 Dog')
                      SizedBox(
                        width: 265, 
                        child: DropdownButtonFormField<String>(
                          value: selectedBreed,
                          items: ['Labrador', 'Poodle', 'Unknown'].map((breed) => DropdownMenuItem(value: breed, child: Text(breed))).toList(),
                          onChanged: (value) => setState(() => selectedBreed = value),
                          decoration: InputDecoration(labelText: "Breed",
                          labelStyle: TextStyle(color: Colors.white), 
                          filled: true,
                          fillColor: const Color.fromARGB(98, 255, 255, 255), 
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), 
                            borderSide: BorderSide.none, 
                          ),
                          ),
                          dropdownColor: Colors.grey[700], 
                        ),
                      ),
                     // SizedBox(height: 30,),
                    if (selectedAnimal == '🐱 Cat')
                      SizedBox(
                        width: 265,
                        child: DropdownButtonFormField<String>(
                          value: selectedBreed,
                          items: ['Siamese', 'Persian', 'Unknown'].map((breed) => DropdownMenuItem(value: breed, child: Text(breed))).toList(),
                          onChanged: (value) => setState(() => selectedBreed = value),
                          decoration: InputDecoration(labelText: "Breed",
                          labelStyle: TextStyle(color: Colors.white), 
                          filled: true,
                          fillColor: const Color.fromARGB(98, 255, 255, 255), 
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), 
                            borderSide: BorderSide.none, 
                          ),
                          ),
                          dropdownColor: Colors.grey[700], 
                        ),
                      ),
                    if (selectedAnimal == 'Other')
                     Mytextfield(controller: customAnimalController,hintText: "Specify Animal",prefixIcon: Icon(Icons.pets,color: Colors.white,),obscureText: false,), 
                      
                      SizedBox(height: 30),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 35, vertical: 8),
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => birthDate = date);
                        },
                        child: Text(
                          birthDate == null
                              ? "Pick Birth Date"
                              : "Birth Date: ${birthDate!.toLocal().toString().split(' ')[0]}",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),

                    SizedBox(height: 20,),
                    Mytextfield(controller: kilosController,hintText: "Weight in kg",prefixIcon: Icon(Icons.scale,color: Colors.white,),obscureText: false,),
                    SizedBox(height: 20,),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50.0),
                      child: TextField(
                          controller: aboutController,
                          cursorColor: Color(0xFF73BDF3), 
                          maxLines: 5, 
                          style: TextStyle(color: Colors.white), 
                          decoration: InputDecoration(
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color.fromARGB(201, 255, 255, 255)), 
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white), 
                            ),
                            fillColor: Color.fromARGB(91, 255, 253, 253), 
                            filled: true, 
                            hintText: "About my pet ❤️", 
                            hintStyle: TextStyle(color: Colors.white), 
                            focusColor: Colors.white, 
                          ),
                        ),
                    ),
          
                    SizedBox(height: 40,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FloatingActionButton(onPressed: () => storageService.uploadImage(),
                        backgroundColor: const Color.fromARGB(125, 255, 255, 255),
                        child: const Icon(Icons.add,color: Color(0xFF6C4C57),),
                        ),
                        SizedBox(width: 20,),
                        CircleAvatar(
                          radius: 80, 
                          backgroundColor: const Color.fromARGB(128, 255, 255, 255), 
                          backgroundImage: imageUrls.isNotEmpty
                              ? NetworkImage(imageUrls.last) 
                              : null, 
                          child: imageUrls.isEmpty
                              ? Icon(Icons.image, size: 50, color: Color(0xFF6C4C57)) 
                              : null, 
                        ),
                        SizedBox(width: 20,),
                        FloatingActionButton(onPressed: () => storageService.deleteImages(imageUrls.last),
                        backgroundColor:  const Color.fromARGB(130, 255, 255, 255),
                        child: const Icon(Icons.remove,color: Color(0xFF6C4C57),),
                        ),
                      ],
                    ),
                    SizedBox(height: 20,),
                    MyButtonForCreation(onTap:() => savePetInfo(imageUrls),text :"Create profile"),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
    },
      );
  }
}


class MyButtonForCreation extends StatelessWidget {

  final Function()? onTap;
  final String text;
  const MyButtonForCreation({super.key,required this.onTap,required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.symmetric(horizontal: 100,vertical: 10),
        decoration: BoxDecoration(color:  Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: Color(0xFF6C4C57)),
          ),
        ),
      ),
    );
  }
}
