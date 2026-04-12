import 'models.dart';

class BatchMasterLogic {
  // --- BATCH KO UPDATE YA SAVE KARNE KI LOGIC ---
  static List<BatchInfo> updateBatchList(List<BatchInfo> existingBatches, BatchInfo newBatch) {
    List<BatchInfo> updatedList = List.from(existingBatches);
    
    // Check karo kya ye batch pehle se hai?
    int idx = updatedList.indexWhere((b) => b.batch.toUpperCase() == newBatch.batch.toUpperCase());
    
    if (idx != -1) {
      // Agar batch pehle se hai, toh sirf details update karo (MRP, Rate, Exp)
      updatedList[idx] = newBatch;
    } else {
      // Agar naya batch hai, toh list mein jod do
      updatedList.add(newBatch);
    }
    
    // Sort karein taaki naye batches ya valid expiry wale upar rahein (Optional)
    return updatedList;
  }
}
