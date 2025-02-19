import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class StorageService with ChangeNotifier{

  final firebaseStorage = FirebaseStorage.instance;

  //images are as download URL's
  List<String> _imageURL = [];

  //upload status
  bool _isUploading = false;
  //loading status
  bool _isLoading = false;

  List<String> get imageURL => _imageURL;
  bool get isUploading => _isUploading;//getters
  bool get isLoading => _isLoading;

  Future<void> fetchImages() async{
    _isLoading = true;
    //save the list under the directory : uploaded_images/
    final ListResult result = await firebaseStorage.ref('uploaded_images/').listAll();
    //get url for each image
    final url = await Future.wait(result.items.map((ref)=> ref.getDownloadURL()));
    //update urls
    _imageURL = url;

    _isLoading = false;
    //notify the listeners to update the ui
    notifyListeners();
  }

  Future<void> deleteImages(String imageUrl) async{
    try{
      _imageURL.remove(imageUrl);//remove from local list
      //get path name and delete also from firebase
      final String path = extractPath(imageUrl);
      await firebaseStorage.ref(path).delete();
    }
    catch(e){
      print("Canno delete image: $e");
    }
    notifyListeners();
  }

  String extractPath(String url)
  {
    Uri uri = Uri.parse(url);
    String encodedPath = uri.pathSegments.last;
    return Uri.decodeComponent(encodedPath);
  }

  Future<void> uploadImage() async{
    _isUploading = true;
    notifyListeners();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if(image == null)
    {
      return;
    }
    File file = File(image.path);
    try{
      String filePath = 'uploaded_images/${DateTime.now()}.png';
      //upload to firebase
      await firebaseStorage.ref(filePath).putFile(file);
      //fetch download url
      String downloadUrl = await firebaseStorage.ref(filePath).getDownloadURL();
      _imageURL.add(downloadUrl);
      notifyListeners();
    }
    catch(e){
      print("Error uploading : $e");
    }finally{
      _isUploading = false;
      notifyListeners();
    }
  }
}