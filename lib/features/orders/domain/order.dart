class Order {
  const Order(
      {required this.id,
      required this.number,
      required this.customerId,
      required this.customerName,
      required this.itemName,
      required this.estimatedPrice,
      required this.commitmentAmount,
      required this.commitmentStatus,
      required this.status,
      required this.createdAt,
      this.supplierName,
      this.purchasePrice,
      this.actualLoss = 0,
      this.refundAmount = 0});
  final String id,
      number,
      customerId,
      customerName,
      itemName,
      commitmentStatus,
      status;
  final int estimatedPrice, commitmentAmount, actualLoss, refundAmount;
  final String? supplierName;
  final int? purchasePrice;
  final DateTime createdAt;
  bool get canReceiveCommitment =>
      status == 'Pemesanan' && commitmentStatus == 'Belum diterima';
  bool get canPurchase =>
      commitmentStatus == 'Diterima' && status == 'Pemesanan';
  bool get canConfirmOwnership => status == 'Barang dibeli';
  bool get isReadyForContract => status == 'Siap akad';
  bool get isCancelled => status == 'Batal';
}
