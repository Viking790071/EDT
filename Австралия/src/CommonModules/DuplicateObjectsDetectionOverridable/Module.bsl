#Region Public

// Defining metadata objects, in whose manager modules parametrization of duplicates search 
// algorithm is available using the DuplicatesSearchParameters, OnDuplicatesSearch, and 
// CanReplaceItems export procedures.
//
// Parameters:
//   Objects - Map - objects, whose manager modules contain export procedures.
//       ** Key - String - full name of the metadata object attached to the "Search and deletion of duplicates" subsystem.
//                              For example, "Catalog.Counterparties".
//       ** Value - String - names of export procedures defined in the manager module.
//                              You can specify:
//                              "DuplicatesSearchParameters",
//                              "OnDuplicatesSearch",
//                              "CanReplaceItems".
//                              Every name must start with a new line.
//                              Empty string means that all procedures are determined in the manager module.
//
// Example:
//  1. All procedures are defined in the catalog:
//  Objects.Insert(Metadata.Catalogs.Counterparties.FullName(), "");
//
//  2. Only the DuplicatesSearchParameters and OnDuplicatesSearch procedures are defined:
//  Objects.Insert(Metadata.Catalogs.ProjectTasks.FullName(),"DuplicatesSearchParameters
//                   |OnDuplicatesSearch");
//
Procedure OnDefineObjectsWithSearchForDuplicates(Objects) Export
	
	
	
EndProcedure

#EndRegion
