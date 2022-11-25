#Region Public

// Defining metadata objects, in whose manager modules attribute editing is prohibited using the 
// GetObjectAttributesToLock export function.
//
// Function - GetObjectAttributesToLock returns the Array value - strings in format
// AttributeName[;FormItemName,...], where AttributeName is an object attribute name and 
// FormItemName is the mane of the form item linked to the attribute. For example, "ObjectAuthor", "FieldAuthor".
//
// The label field linked to an attribute is not locked. To lock it, specify the label item after 
// the semicolons.
//
// Parameters:
//   Objects - Map - as a key, specify a full metadata object name attached to the "Object attribute 
//             lock" subsystem. As a value, specify an empty string.
//             
//
// Example:
//   Objects.Insert(Metadata.Documents.SalesOrder.FullName(), "");
//
//   The code is placed in the manager module of the SalesOrder document:
//   // See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
//   Fuction GetObjectAttributesToLock() Export
//   	AttributesToLock = New Array;
//   	AttributesToLock.Add("Company"); // lock editing the Company attribute.
//   	Return AttributesToLock;
//   EndFunction
//
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export
	
	
	
EndProcedure

#EndRegion
