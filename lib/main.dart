//import 'package:flutter/material.dart';
//import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:test_decode_app/gltf_decoder.dart';



Future<The3DGltf> fetch3DGltf() async {
  final response = await http
      .get(Uri.parse('https://upgradec.exrx.net/index.php/ccm/api/1.0/files/11907/encodedFile'));

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return The3DGltf.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load data');
  }
}

class The3DGltf {
  String value1;
  String value2;

  The3DGltf({
    required this.value1,
    required this.value2,
  });

  factory The3DGltf.fromJson(Map<String, dynamic> json) {
    return The3DGltf(
      value1: json['value1'] as String,
      value2: json['value2'] as String,
    );
  }
}

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<The3DGltf> future3DGltf;

  @override
  void initState() {
    super.initState();
    future3DGltf = fetch3DGltf();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fetch Data',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Fetch Data'),
        ),
        body: Center(
          child: FutureBuilder<The3DGltf>(
            future: future3DGltf,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // Get gltf
                Map<String, dynamic> egltf = jsonDecode(snapshot.data!.value1);

                // Get etkn
                String etkn = snapshot.data!.value2;

                //print("EGLTF: $egltf");
                //print(etkn);
                var result = decodeGltfAndToken(egltf, etkn);
                print("RESULT: $result");

                return Text(snapshot.data!.value2);
              } else if (snapshot.hasError) {
                return Text('${snapshot.error}');
              }

              // By default, show a loading spinner.
              return const CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }
}


// void main() {
//   // This example uses the Google Books API to search for books about http.
//   // https://developers.google.com/books/docs/overview
//
// }

// void main(List<String> arguments) async {
//   // This example uses the Google Books API to search for books about http.
//   // https://developers.google.com/books/docs/overview
//   var url =
//   Uri.https('upgradec.exrx.net', '/index.php/ccm/api/1.0/files/11883/encodedFile');
//
//   // Await the http get response, then decode the json-formatted response.
//   var response = await http.get(url);
//   if (response.statusCode == 200) {
//     var jsonResponse =
//     convert.jsonDecode(response.body) as Map<String, dynamic>;
//     print(jsonResponse);
//   } else {
//     print('Request failed with status: ${response.statusCode}.');
//   }
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('Model Viewer')),
//         body: const ModelViewer(
//           backgroundColor: Color.fromARGB(0xFF, 0xEE, 0xEE, 0xEE),
//           src: 'assets/trex/scene.gltf',
//           alt: 'A 3D model of an astronaut',
//           ar: false,
//           autoRotate: false,
//           iosSrc: 'https://modelviewer.dev/shared-assets/models/Astronaut.usdz',
//           disableZoom: true,
//         ),
//       ),
//     );
//   }
// }