#Region Public

// Allows you to make changes to the tree with full-text search sections displayed upon selecting a search area.
// By default, the sections tree is formed based on subsystems included in the configuration.
// The tree structure is described in the DataProcessor.FullTextSearchInData.Form.SearchAreaChoice form.
// All columns not specified in parameters will be calculated automatically.
// If you need to build a sections tree on your own, save the column content.
//
// Parameters:
//   SearchSections - ValueTree - search areas. Contains the following columns:
//       ** Section   - String   - a presentation of a section: subsystem or metadata object.
//       ** Picture - Picture - a section picture, recommended for root sections only.
//       ** MetadataObject - CatalogRef.MetadataObjectsIDs - specified only for metadata objects, 
//                     leave it blank for sections.
// Example:
//
//	NewSection = SearchSections.Rows.Add().
//	NewSection.Section = "Main".
//	NewSection.Picture = PictureLib._DemoSectionMain.
//	
//	MetadataObject = Metadata.Documents._DemoCustomerInvoice.
//	
//	If AccessRight("View", MetadataObject)
//		And Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject) then
//		
//		NewSectionObject = NewSection.Rows.Add().
//		NewSectionObject.Section = MetadataObject.ListPresentation.
//		NewSectionObject.MetadataObject = Common.MetadataObjectID(MetadataObject).
//	EndIf
//
Procedure OnGetFullTextSearchSections(SearchSections) Export
	
	
	
EndProcedure

#EndRegion