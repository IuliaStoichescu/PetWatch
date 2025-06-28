import 'dart:math';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pet_watch/login_signin/myTextField.dart';
import 'package:pet_watch/login_signin/services/storage_service.dart';
import 'package:provider/provider.dart';

class AddPet extends StatefulWidget {
  final String? petId;
  final Map<String, dynamic>? existingPetData;
  const AddPet({super.key, this.petId, this.existingPetData});
  
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
  
  
  final List<String> dogBreeds = [
  'Labrador Retriever',
  'German Shepherd',
  'Golden Retriever',
  'French Bulldog',
  'Bulldog',
  'Poodle',
  'Beagle',
  'Rottweiler',
  'Yorkshire Terrier',
  'Boxer',
  'Dachshund',
  'Siberian Husky',
  'Great Dane',
  'Doberman Pinscher',
  'Cavalier King Charles Spaniel',
  'Miniature Schnauzer',
  'Shih Tzu',
  'Australian Shepherd',
  'Pomeranian',
  'Boston Terrier',
  'Havanese',
  'Shetland Sheepdog',
  'Bernese Mountain Dog',
  'Cocker Spaniel',
  'Chihuahua',
  'Basset Hound',
  'Border Collie',
  'Maltese',
  'Akita',
  'Weimaraner',
  'Vizsla',
  'St. Bernard',
  'Newfoundland',
  'Collie',
  'Alaskan Malamute',
  'Bull Terrier',
  'English Springer Spaniel',
  'Whippet',
  'Papillon',
  'Pointer',
  'Bichon Frise',
  'Belgian Malinois',
  'Shiba Inu',
  'Rhodesian Ridgeback',
  'Cane Corso',
  'Australian Cattle Dog',
  'Chow Chow',
  'English Setter',
  'Irish Setter',
  'Caucasian Shepperd',
  'Unknown',
];

final List<String> catBreeds = [
  'Siamese',
  'Persian',
  'Maine Coon',
  'Ragdoll',
  'Bengal',
  'Sphynx',
  'British Shorthair',
  'Scottish Fold',
  'Abyssinian',
  'Birman',
  'Oriental Shorthair',
  'American Shorthair',
  'Norwegian Forest Cat',
  'Devon Rex',
  'Russian Blue',
  'Savannah',
  'Himalayan',
  'Manx',
  'Turkish Van',
  'Balinese',
  'Exotic Shorthair',
  'Tonkinese',
  'Chartreux',
  'Bombay',
  'Cornish Rex',
  'Selkirk Rex',
  'Egyptian Mau',
  'Japanese Bobtail',
  'LaPerm',
  'Munchkin',
  'Ocicat',
  'Ragamuffin',
  'Turkish Angora',
  'Unknown',
];


  @override
  void initState(){
    super.initState();
    fetchImages();

    if (widget.existingPetData != null) {
    final data = widget.existingPetData!;
    nameController.text = data['name'] ?? '';
    aboutController.text = data['about'] ?? '';
    kilosController.text = data['kilograms']?.toString().replaceAll(' kg', '') ?? '';
    selectedSex = data['sex'];
    selectedAnimal = data['animalType'] == 'Other' ? 'Other' : data['animalType'];
    selectedBreed = data['breed'];
    birthDate = data['birthDate'] != null && data['birthDate'] != "Not provided"
        ? DateTime.tryParse(data['birthDate'])
        : null;
    customAnimalController.text = selectedAnimal == 'Other' ? data['animalType'] ?? '' : '';
  }
  }

  void savePetInfo(List<String> image) async {
  final User user = FirebaseAuth.instance.currentUser!;
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  DocumentReference userRef = firestore.collection("users").doc(user.uid);
  final bool isEdit = widget.petId != null;

  try {
    DocumentSnapshot userSnapshot = await userRef.get();
    if (!userSnapshot.exists) {
      await userRef.set({
        "uid": user.uid,
        "email": user.email,
        "createdAt": FieldValue.serverTimestamp(),
      });
    }

    if (isEdit) {
      // Edit existing pet
      final petRef = userRef.collection("pets").doc(widget.petId);
      await petRef.collection("pet_info").doc("details").update({
        "name": nameController.text.trim(),
        "sex": selectedSex ?? "Unknown",
        "imageUrl": image.isNotEmpty
            ? image.last
            : widget.existingPetData?["imageUrl"] ?? "",
        "about": aboutController.text.trim(),
        "kilograms": "${kilosController.text.trim()} kg",
        "animalType": selectedAnimal == 'Other'
            ? customAnimalController.text.trim()
            : selectedAnimal,
        "breed": selectedBreed ?? "Unknown",
        "birthDate": birthDate?.toIso8601String() ?? "Not provided",
      });
    } else {
      // Create new pet
      DocumentReference petRef = await userRef.collection("pets").add({
        "timestamp": FieldValue.serverTimestamp(),
      });

      await petRef.collection("pet_info").doc("details").set({
        "name": nameController.text.trim(),
        "sex": selectedSex ?? "Unknown",
        "imageUrl": image.isNotEmpty ? image.last : "",
        "about": aboutController.text.trim(),
        "kilograms": "${kilosController.text.trim()} kg",
        "animalType": selectedAnimal == 'Other'
            ? customAnimalController.text.trim()
            : selectedAnimal,
        "breed": selectedBreed ?? "Unknown",
        "birthDate": birthDate?.toIso8601String() ?? "Not provided",
      });
    }

    Navigator.pop(context, true); // Close the form and return to previous screen

    // Clear the form
    setState(() {
      nameController.clear();
      aboutController.clear();
      kilosController.clear();
      selectedSex = null;
      selectedAnimal = null;
      selectedBreed = null;
      birthDate = null;
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
    final l10n = AppLocalizations.of(context)!;
    final bool isEdit = widget.petId != null;
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
                                Text(isEdit? l10n.editTitle : l10n.createTitle,style: TextStyle(fontSize: 20,color: Colors.white),),
                                Text(l10n.yourPetProfile,style: TextStyle(fontSize: 20,color: Colors.white),),
                                Text(!isEdit? l10n.guideNote:"",style: TextStyle(color: Colors.white))
                              ],
                            ),
                            Lottie.asset("assets/cat_play.json",width: 150,height: 150),
                          ],
                        ),
                    ),
                    if(!isEdit)...[  Text(l10n.onboardingStep1, style: TextStyle(color: Colors.white)),
                    Text(l10n.onboardingStep2, style: TextStyle(color: Colors.white)),
                    SizedBox(height: 10),
                    Divider(thickness: 0.5, color: Color.fromARGB(255, 44, 44, 44)),
                    SizedBox(height: 10),
                    Text(l10n.onboardingStep3, style: TextStyle(color: Colors.white)),
                    Text(l10n.onboardingStep4, style: TextStyle(color: Colors.white)),
                    Text(l10n.onboardingStep5, style: TextStyle(color: Colors.white)),
                    Text(l10n.onboardingStep6, style: TextStyle(color: Colors.white)),
                    Image.asset("assets/off.png", width: 150, height: 150),
                    SizedBox(height: 10),
                    Divider(thickness: 0.5, color: Color.fromARGB(255, 44, 44, 44)),
                    SizedBox(height: 10),
                    Text(l10n.onboardingStep7, style: TextStyle(color: Colors.white)),
                    Text(l10n.onboardingStep8, style: TextStyle(color: Colors.white)),
                    Text(l10n.onboardingStep9, style: TextStyle(color: Colors.white)),
                    Text(l10n.onboardingStep10, style: TextStyle(color: Colors.white)),
                    Image.asset("assets/on.png",width: 150,height: 150,),SizedBox(height: 30,),]
                    else...[

                    ],                 
                    Text(l10n.profile,style: TextStyle(color: Colors.white,fontSize: 30,decoration: TextDecoration.underline,decorationColor: const Color.fromARGB(255, 255, 255, 255),),),
                    SizedBox(height: 30,),
                    Mytextfield(controller: nameController,hintText: l10n.petNameHint,prefixIcon: Icon(Icons.pets,color: Colors.white,),obscureText: false,),
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
                          labelText: l10n.genderLabel,
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
                        items: ["🐶 Dog","🐱 Cat","Other"].map((animal) => 
                        DropdownMenuItem(
                          
                          value: animal,child: Text(animal,style: TextStyle(color: Colors.white),))).toList(),
                        onChanged: (value)=>setState(() {
                          selectedAnimal=value;
                          selectedBreed = null;
                        }),
                        decoration: InputDecoration(
                          labelText: l10n.animalTypeLabel,
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
                    SizedBox(height: 20,),
                    if (selectedAnimal == '🐶 Dog')
                      SizedBox(
                        width: 265, 
                        child: DropdownButtonFormField<String>(
                          value: selectedBreed,
                          isExpanded: true,
                          items: dogBreeds.map((breed) => DropdownMenuItem(value: breed, child: Text(breed))).toList(),
                          onChanged: (value) => setState(() => selectedBreed = value),
                          decoration: InputDecoration(labelText: l10n.breed,
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
                    if (selectedAnimal == "🐱 Cat")
                      SizedBox(
                        width: 265,
                        child: DropdownButtonFormField<String>(
                          value: selectedBreed,
                          isExpanded: true,
                          items: catBreeds.map((breed) => DropdownMenuItem(value: breed, child: Text(breed))).toList(),
                          onChanged: (value) => setState(() => selectedBreed = value),
                          decoration: InputDecoration(labelText: l10n.breed,
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
                    if (selectedAnimal == "Other")
                     Mytextfield(controller: customAnimalController,hintText: l10n.specifyAnimalHint,prefixIcon: Icon(Icons.pets,color: Colors.white,),obscureText: false,), 
                      
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
                              ? l10n.birthDatePrompt
                              : l10n.birthDateLabel(birthDate!.toLocal().toString().split(' ')[0]),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),

                    SizedBox(height: 20,),
                    Mytextfield(controller: kilosController,hintText: l10n.weightHint,prefixIcon: Icon(Icons.scale,color: Colors.white,),obscureText: false,),
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
                            hintText: l10n.aboutHint, 
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
                        /*FloatingActionButton(onPressed: () => storageService.deleteImages(imageUrls.last),
                        backgroundColor:  const Color.fromARGB(130, 255, 255, 255),
                        child: const Icon(Icons.remove,color: Color(0xFF6C4C57),),
                        ),*/
                      ],
                    ),
                    SizedBox(height: 20,),
                    MyButtonForCreation(onTap:() => savePetInfo(imageUrls),text: isEdit ? l10n.editButton : l10n.createButton),
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
