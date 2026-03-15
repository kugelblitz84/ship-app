import 'package:flutter/foundation.dart';

class TripModel {
  String tripId;
  String from;
  String to;
  String date;
  bool isEdited;
  CompanyAndShipInfo companyAndShipInfo;
  ProductInfo? product;
  String rate;
  String totalBill;
  TripModel({
    //this.id,
    required this.tripId,
    required this.from,
    required this.to,
    required this.date,
    this.isEdited = false,
    required this.companyAndShipInfo,
    required this.rate,
    required this.totalBill,
    this.product,
  });

  factory TripModel.fromMap(
    Map<String, dynamic> map, {
    String? fallbackTripId,
  }) {
    String readString(String key) {
      final value = map[key];
      if (value == null) return '';
      return value.toString();
    }

    var tripIdValue = readString('tripId').trim();
    if (tripIdValue.isEmpty) {
      tripIdValue = readString('id').trim();
    }
    if (tripIdValue.isEmpty) {
      tripIdValue = (fallbackTripId ?? '').trim();
    }

    final companyAndShipValue = map['companyAndShipInfo'];
    if (companyAndShipValue is! Map<String, dynamic>) {
      debugPrint(
        'TripModel.fromMap: missing/invalid companyAndShipInfo for tripId=$tripIdValue',
      );
    }
    final companyAndShipMap = companyAndShipValue is Map<String, dynamic>
        ? companyAndShipValue
        : <String, dynamic>{};

    final shipName = (companyAndShipMap['shipName']?.toString() ?? '').trim();
    final companyName = (companyAndShipMap['companyName']?.toString() ?? '')
        .trim();

    if (shipName.isEmpty || companyName.isEmpty) {
      debugPrint(
        'TripModel.fromMap: empty company/ship name for tripId=$tripIdValue (companyName="$companyName", shipName="$shipName")',
      );
    }

    ProductInfo? parseSingleProduct(dynamic value) {
      if (value is Map<String, dynamic>) {
        return ProductInfo.fromMap(value);
      }
      if (value is Map) {
        return ProductInfo.fromMap(Map<String, dynamic>.from(value));
      }
      if (value == null) return null;
      final productName = value.toString().trim();
      if (productName.isEmpty) return null;
      return ProductInfo(productName: productName, quantity: '1', unit: 'unit');
    }

    ProductInfo? parsedProduct = parseSingleProduct(map['product']);
    if (parsedProduct == null) {
      final productsValue = map['products'];
      if (productsValue is Iterable) {
        final legacyFirst = productsValue.cast<dynamic>().firstWhere(
          (item) => parseSingleProduct(item) != null,
          orElse: () => null,
        );
        parsedProduct = parseSingleProduct(legacyFirst);
      }
    }

    final rateValue = readString('rate');
    String totalBillValue = readString('totalBill');
    if (totalBillValue.trim().isEmpty) {
      totalBillValue = readString('fundOwed');
    }
    if (totalBillValue.trim().isEmpty) {
      final rate = double.tryParse(rateValue.replaceAll(',', '').trim()) ?? 0;
      final quantity = double.tryParse(
        (parsedProduct?.quantity ?? '').replaceAll(',', '').trim(),
      );
      if (quantity != null) {
        final computed = rate * quantity;
        totalBillValue = computed.toInt().toString();
      }
    }

    return TripModel(
      tripId: tripIdValue,
      from: readString('from'),
      to: readString('to'),
      date: readString('date'),
      isEdited: map['isEdited'] == true,
      companyAndShipInfo: CompanyAndShipInfo(
        shipName: shipName,
        companyName: companyName,
      ),
      rate: rateValue,
      totalBill: totalBillValue,
      product: parsedProduct,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'from': from,
      'to': to,
      'date': date,
      'isEdited': isEdited,
      'companyAndShipInfo': companyAndShipInfo.toMap(),
      'product': product?.toMap(),
      'rate': rate,
      'totalBill': totalBill,
    };
  }

  @Deprecated('Use totalBill instead.')
  String get fundOwed => totalBill;

  @Deprecated('Use totalBill instead.')
  set fundOwed(String value) => totalBill = value;

  @Deprecated('Trip-level received is no longer tracked.')
  String get fundRecieved => '0';

  @Deprecated('Trip-level received is no longer tracked.')
  set fundRecieved(String value) {}
}

class CompanyAndShipInfo {
  // Names are persisted as the source of identity.
  String shipName;
  String companyName;

  CompanyAndShipInfo({required this.shipName, required this.companyName});

  Map<String, dynamic> toMap() {
    return {'shipName': shipName, 'companyName': companyName};
  }
}

class ProductInfo {
  String productName;
  String? desctription;
  String quantity;
  String unit;

  ProductInfo({
    required this.productName,
    this.desctription,
    required this.quantity,
    required this.unit,
  });

  factory ProductInfo.fromMap(Map<String, dynamic> map) {
    String readString(String key) {
      final value = map[key];
      if (value == null) return '';
      return value.toString();
    }

    final descriptionValue = map.containsKey('desctription')
        ? map['desctription']
        : map['description'];

    return ProductInfo(
      productName: readString('productName'),
      desctription: descriptionValue?.toString(),
      quantity: readString('quantity'),
      unit: readString('unit'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'desctription': desctription,
      'quantity': quantity,
      'unit': unit,
    };
  }
}
