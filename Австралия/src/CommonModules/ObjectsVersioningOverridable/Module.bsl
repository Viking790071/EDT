#Region Public

// Called to get versioned spreadsheet documents when writing the object version. 
// When the object version report requires replacing technical object tabular section by its 
// spreadsheet document presentation, the spreadsheet document is attached to the object version.
//
// Parameters:
//  Reference             - AnyRef - versioned configuration object.
//  SpreadsheetDocuments - Structure   - contains data:
//   * Key     - String    - spreadsheet document name;
//   * Value - Structure - contains fields:
//    ** Description - String            - a spreadsheet document description.
//    ** Data       - SpreadsheetDocument - versioned spreadsheet document.
Procedure OnReceiveObjectSpreadsheetDocuments(Ref, SpreadsheetDocuments) Export
	
EndProcedure

// Called after parsing the object version that is read from the register. This can be used for 
//  additional processing of the version parsing result.
// 
// Parameters:
//  Reference   - AnyRef - versioned configuration object.
//  Result - Structure - result of parsing the version by the versioning subsystem.
//
Procedure AfterParsingObjectVersion(Ref, Result) Export
	
EndProcedure

// Called after defining object attributes from the form
// InformationRegister.ObjectVersions.SelectObjectAttributes.
// 
// Parameters:
//  Reference           - AnyRef       - versioned configuration object.
//  AttributeTree - FormDataTree - object attribute tree.
//
Procedure OnSelectObjectAttributes(Ref, AttributeTree) Export
	
EndProcedure

// Called upon receiving object attribute presentation.
// 
// Parameters:
//  Reference                - AnyRef - versioned configuration object.
//  AttributeName          - String      - AttributeName as it is set in Designer.
//  AttributeDescription - String      - an output parameter. You can overwrite the retrieved synonym.
//  Visibility             - Boolean      - display attribute in version reports.
//
Procedure OnDetermineObjectAttributeDescription(Ref, AttributeName, AttributeDescription, Visibility) Export
	
EndProcedure

// Supplements the object with attributes that are stored separately from the object or in the 
// internal part of the object that is not displayed in reports.
//
// Parameters:
//  Object - object - versioned object.
//  AdditionalAttributes - ValueTable - collection of additional attributes that are to be saved 
//                                              with the object version:
//   * ID - Arbitrary - unique attribute ID. Required to restore from the object version in case the 
//                                    attribute value is stored separately from the object.
//   * Description - String - an attribute description.
//   * Value - Arbitrary - attribute value.
Procedure OnPrepareObjectData(Object, AdditionalAttributes) Export 
	
	
	
EndProcedure

// Restores object attributes values stored separately from the object.
//
// Parameters:
//  Object - object - versioned object.
//  AdditionalAttributes - ValueTable - collection of addtitional attributes that were saved with 
//                                              the object version:
//   * ID - Arbitrary - unique attribute ID.
//   * Description - String - an attribute description.
//   * Value - Arbitrary - attribute value.
Procedure OnRestoreObjectVersion(Object, AdditionalAttributes) Export
	
	
	
EndProcedure

#EndRegion