import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pet_watch/login_signin/myTextField.dart';

class AddPet extends StatefulWidget {
  const AddPet({super.key});

  @override
  State<AddPet> createState() => _AddPetState();
}

class _AddPetState extends State<AddPet> {
  //fields for pet profile
  final TextEditingController nameController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  String? selectedSex;
  String imageUrl = ""; 

  @override
  Widget build(BuildContext context) {
    return Container(
         decoration: BoxDecoration(
            color: Color(0xFF6C4C57), 
            borderRadius: BorderRadius.circular(15), 
          ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 10,width: 30,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20,),
                      Column(
                        children: [
                          Text("Create ",style: TextStyle(fontSize: 20,color: Colors.white),),
                          Text("your pet's profile!",style: TextStyle(fontSize: 20,color: Colors.white),),
                          Text("(Guide. Continue below ⬇️)",style: TextStyle(color: Colors.white))
                        ],
                      ),
                      Lottie.asset("assets/cat_play.json",width: 150,height: 150),
                    ],
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
                  SizedBox(height: 50,),
                  Text("Pet Profile",style: TextStyle(color: Colors.white,fontSize: 30,decoration: TextDecoration.underline,decorationColor: const Color.fromARGB(255, 255, 255, 255),),),
                  SizedBox(height: 50,),
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
                        //labelText: "Sex",
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
                  )
                ],
              ),
            ),
          ),
        ),
    );
  }
}
