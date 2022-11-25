#Region Public

// Defines a list of catalogs available for import using the "Data import from file" subsystem.
//
// Parameters:
//  CatalogsToImport - ValuesTable - a list of the catalogs, to which data can be imported.
//      * FullName - String - a full catalog name (as in metadata).
//      * Presentation - String - a catalog presentation in the selection list.
//      * AppliedImport - Boolean - if True, then the catalog uses its own import algorithm and the 
//                                      functions are defined in the manager module.
//
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	
	
EndProcedure

#EndRegion