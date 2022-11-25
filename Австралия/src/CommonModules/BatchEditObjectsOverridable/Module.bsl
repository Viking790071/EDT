#Region Public

// Defining metadata objects, in whose manager modules group attribute editing is prohibited.
// 
//
// Parameters:
//   Objects - Map - set the key to the full name of the metadata object attached to the "Batch 
//                            object modification" subsystem.
//                            In addition, the value can include export function names:
//                            "AttributesToSkipInBatchProcessing" and
//                            "AttributesToEditInBatchProcessing".
//                            Every name must start with a new line.
//                            Setting to "*" means that both functions are defined in the manager module.
//
// Example: 
//   Objects.Insert(Metadata.Documents.PurchaserOrders.FullName(), "*"); // both functions are defined.
//   Objects.Insert(Metadata.BusinessProcesses.JobWithRoleBasedAddressing.FullName(), "AttributesToEditInBatchProcessing");
//   Objects.Insert(Metadata.Catalogs.Partners.FullName(), "AttributesToEditInBatchProcessing
//		|AttributesToSkipInBatchProcessing");
//
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	
	
	
EndProcedure

#EndRegion
