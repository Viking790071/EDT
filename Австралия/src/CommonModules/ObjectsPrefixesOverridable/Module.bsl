#Region Public

// Event handler on the object number change.
// The handler is intended to compute a basic object number when it cannot be got in a standard way 
// without information loss.
// The handler is called only if processed object numbers and codes were generated in a non-standard 
// way, i.e. not in the SSL number and code format.
//
// Parameters:
//  Object - DocumentObject, BusinessProcessObject, TaskObject - a data object whose basic number is 
//           to be defined.
//  Number - String - a number of the current object a basic number is to be got from.
//  BasicNumber - String - a basic object number.
//           A basic object number is an object number without all prefixes (infobase prefix, 
//           company prefix, department prefix, custom prefix, etc.).
//           
//  StandardProcessing - Boolean - a standard processing flag. The default value is True.
//           If the parameter in the handler is set to False, the standard processing will not be 
//           performed.
//           The standard processing gets a basic code to the right of the first non-numeric character.
//           For example, for code AA00005/12/368, the standard processing returns 368.
//           However, the basic object code is equal to 5/12/368.
//
Procedure OnChangeNumber(Object, Val Number, BasicNumber, StandardProcessing) Export
	
	
	
EndProcedure

// Event handler on the object code change.
// The handler is intended to compute a basic object code when it cannot be got in a standard way 
// without information loss.
// The handler is called only if processed object numbers and codes were generated in a non-standard 
// way, i.e. not in the SSL number and code format.
//
// Parameters:
//  Object - CatalogObject, ChartOfCharacteristicTypesObject - a data object whose basic code is to 
//           be defined.
//  Code - String - a code of the current object from which a basic code is to be got.
//  BasicCode - String - a basic object code. A basic object code is an object code without all 
//           prefixes (infobase prefix, company prefix, department prefix, custom prefix, etc.).
//           
//  StandardProcessing - Boolean - a standard processing flag. The default value is True.
//           If the parameter in the handler is set to False, the standard processing will not be 
//           performed.
//           The standard processing gets a basic code to the right of the first non-numeric character.
//           For example, for code AA00005/12/368, the standard processing returns 368.
//           However, the basic object code is equal to 5/12/368.
//
Procedure OnChangeCode(Object, Val Code, BasicCode, StandardProcessing) Export
	
EndProcedure

// In the procedure, fill in the Objects parameter for metadata objects for which a reference to a 
// company is included in an attribute with name different from the standard name Company.
//
// Parameters:
//  Objects - ValueTable - a table with columns:
//     * Object - MetadataObject - a metadata object, for which an attribute containing a reference 
//                to a company is specified.
//     * Attribute - String - a name of the attribute containing a reference to a company.
//
Procedure GetPrefixGeneratingAttributes(Objects) Export
	
	
	
EndProcedure

#EndRegion
