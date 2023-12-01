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


int b602num(String asc) {
  const String validChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz23456789";

  if (!validChars.contains(asc)) {
    print("BASE60 decoder received symbol out of range: $asc");
    return -1; // or handle the error as needed
  }

  int num = asc.codeUnitAt(0);

  if (num >= 97) {
    return num - 97 + 26;
  } else if (num >= 65) {
    return num - 65;
  } else {
    return num - 50 + 52;
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
      List<List<String>> unshMatrix = List.generate(6, (i) => List.filled(5, '0'));
      for (int i = 0; i < 3; i++) {
        String encVal = accessor['max'] != null ? (accessor['max'][i].toString().substring(accessor['max'][i].toString().length - 6).substring(0, 5)) : '00000';
        for (int j = 0; j < 5; j++) {
          unshMatrix[i][j] = encVal[j];
        }
      }

      for (int i = 0; i < 3; i++) {
        String encVal = accessor['min'] != null ? (accessor['min'][i].toString().substring(accessor['min'][i].toString().length - 6).substring(0, 5)) : '00000';
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
      decKey = BigInt.parse(decKey).toString(); // Convert to BigInt to remove leading zeros

      // Update the count in the accessor
      accessor['count'] = BigInt.parse(decKey);
    }
  }

  List<int> deshOffsetList = List.from(unshOffsetList)..sort();
  List<int> unshOffsetListNorm = unshOffsetList.map((x) => deshOffsetList.indexOf(x)).toList();

  //List<Map<String, dynamic>> egltfAnimationsChannels = (egltf['animations'] as List<Map<String, dynamic>>)[0]['channels'] as List<Map<String, dynamic>>;
  List<dynamic> animations = egltf['animations'] as List<dynamic>;
  Map<String, dynamic> firstAnimation = animations[0] as Map<String, dynamic>;
  List<Map<String, dynamic>> egltfAnimationsChannels = (firstAnimation['channels'] as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();

  for (int i = 0; i < (egltfAnimationsChannels.length ~/ 10); i++) {
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
