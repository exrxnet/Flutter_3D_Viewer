import 'dart:convert';


int UID_MAX_LENGTH = 10;
int USHF_MAX_LENGTH = 10;
int TIMESTAMP_MAX_LENGTH = 10;
int TIMESTAMP_VALIDITY_MAX_LENGTH = 5;

// class DecodeResult {
//   final String egltfJson;
//   final String decKey;
//   final String decUID;
//   final String decTstp;
//   final String decTstpVal;
//
//   DecodeResult(this.egltfJson, this.decKey, this.decUID, this.decTstp, this.decTstpVal);
// }


int b602num(String symbol) {
  if (symbol.length != 1) {
    throw const FormatException("Input must be a single character");
  }

  int codeUnit = symbol.codeUnitAt(0);

  if (codeUnit >= 'A'.codeUnitAt(0) && codeUnit <= 'Z'.codeUnitAt(0)) {
    return codeUnit - 'A'.codeUnitAt(0);
  } else if (codeUnit >= 'a'.codeUnitAt(0) && codeUnit <= 'z'.codeUnitAt(0)) {
    return codeUnit - 'a'.codeUnitAt(0) + 26;
  } else if (codeUnit >= '2'.codeUnitAt(0) && codeUnit <= '9'.codeUnitAt(0)) {
    return codeUnit - '2'.codeUnitAt(0) + 52;
  } else {
    throw FormatException("Invalid BASE60 symbol: $symbol");
  }
}

Map<String, dynamic> decodeGltfAndToken(Map<String, dynamic> egltf, String etkn) {
  // Calculate header length
  final int headerLength = UID_MAX_LENGTH + USHF_MAX_LENGTH + TIMESTAMP_MAX_LENGTH + TIMESTAMP_VALIDITY_MAX_LENGTH;

  // Extract offset from token
  List<int> unshOffsetList = [];
  for (int i = 0; i < USHF_MAX_LENGTH; i++) {
    int unshOffset = b602num(etkn[headerLength + b602num(etkn[i + UID_MAX_LENGTH])]) % 30;
    unshOffsetList.add(unshOffset);
  }

  // Decode user ID
  String decUID = '';
  for (int i = 0; i < UID_MAX_LENGTH; i++) {
    String uidDec = (b602num(etkn[headerLength + b602num(etkn[i])]) % 10).toString();
    decUID += uidDec;
  }
  decUID = String.fromCharCodes(decUID.runes.toList().reversed);
  decUID = int.parse(decUID).toString();

  // Decode UNIX timestamp
  String decTstp = '';
  for (int i = 0; i < TIMESTAMP_MAX_LENGTH; i++) {
    String tstpDec = (b602num(etkn[headerLength + b602num(etkn[i + UID_MAX_LENGTH + USHF_MAX_LENGTH])]) % 10).toString();
    decTstp += tstpDec;
  }
  decTstp = String.fromCharCodes(decTstp.runes.toList().reversed);
  decTstp = int.parse(decTstp).toString();

  // Decode UNIX timestamp validity interval
  String decTstpVal = '';
  for (int i = 0; i < TIMESTAMP_VALIDITY_MAX_LENGTH; i++) {
    String tstpValDec = (b602num(etkn[headerLength + b602num(etkn[i + UID_MAX_LENGTH + USHF_MAX_LENGTH + TIMESTAMP_MAX_LENGTH])]) % 10).toString();
    decTstpVal += tstpValDec;
  }
  decTstpVal = String.fromCharCodes(decTstpVal.runes.toList().reversed);
  decTstpVal = int.parse(decTstpVal).toString();

  // Recreating decoded hidden keys
  String decKey = '';
  //List<Map<String, dynamic>> egltfAccessors = egltf['accessors'];
  var rawAccessors = egltf['accessors'];
  List<Map<String, dynamic>> egltfAccessors;

  if (rawAccessors is List<dynamic>) {
    egltfAccessors = rawAccessors.map((e) => e as Map<String, dynamic>).toList();
  } else {
    throw Exception('Accessors are not in the expected format');
  }


  for (int k = 0; k < egltfAccessors.length; k++) {
    Map<String, dynamic> accessor = egltfAccessors[k];
    if (accessor['type'] == 'VEC3') {
      // Transcribe data from encoded GLTF into matrix form
      List<List<String>> unshMatrix = List.generate(6, (_) => List.filled(5, '0'));
      for (int i = 0; i < 3; i++) {
        String encVal = (accessor['max'][i].toString().padLeft(6, '0').substring(1, 6));
        for (int j = 0; j < 5; j++) {
          unshMatrix[i][j] = encVal[j];
        }
      }
      for (int i = 0; i < 3; i++) {
        String encVal = (accessor['min'][i].toString().padLeft(6, '0').substring(1, 6));
        for (int j = 0; j < 5; j++) {
          unshMatrix[i + 3][j] = encVal[j];
        }
      }

      decKey = '';
      // Extract matrix shuffling offsets from token and reconstruct the missing key value
      for (int i = 0; i < USHF_MAX_LENGTH; i++) {
        int rowIndex = unshOffsetList[i] ~/ 5;
        int colIndex = unshOffsetList[i] % 5;
        decKey += unshMatrix[rowIndex][colIndex];
      }
      double decimalValue = double.tryParse(decKey) ?? 0.0;
      decKey = BigInt.from(decimalValue).toString();

      //decKey = BigInt.parse(decKey).toString(); // Convert to BigInt to remove leading zeros

      // Update the count in the accessor
      accessor['count'] = BigInt.parse(decKey);
    }
  }

  List<int> deshOffsetList = List.from(unshOffsetList)..sort();
  List<int> unshOffsetListNorm = unshOffsetList.map((e) => deshOffsetList.indexOf(e)).toList();

  //List<Map<String, dynamic>> egltfAnimationsChannels = egltf['animations'][0]['channels'];
  List<Map<String, dynamic>> egltfAnimationsChannels;
  var animations = egltf['animations'];

  if (animations is List<dynamic> && animations.isNotEmpty) {
    var firstAnimation = animations[0];
    if (firstAnimation is Map<String, dynamic> && firstAnimation.containsKey('channels')) {
      var channels = firstAnimation['channels'];
      if (channels is List<dynamic>) {
        egltfAnimationsChannels = channels.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Channels are not in the expected format');
      }
    } else {
      throw Exception('First animation is not in the expected format');
    }
  } else {
    throw Exception('Animations are not in the expected format');
  }

  for (int i = 0; i < (egltfAnimationsChannels.length / 10).floor(); i++) {
    List<int> deorderedIndexVals = [];
    for (int j = 0; j < 10; j++) {
      deorderedIndexVals.add(egltfAnimationsChannels[i * 10 + j]['target']['node']);
    }
    for (int j = 0; j < 10; j++) {
      egltfAnimationsChannels[i * 10 + unshOffsetListNorm[j]]['target']['node'] = deorderedIndexVals[j];
    }
  }

  return {
    'egltf': egltf,
    'decKey': decKey,
    'decUID': decUID,
    'decTstp': decTstp,
    'decTstpVal': decTstpVal,
  };
}
