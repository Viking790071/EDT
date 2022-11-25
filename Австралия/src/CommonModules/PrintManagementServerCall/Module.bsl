#Region Public

////////////////////////////////////////////////////////////////////////////////
// Operations with office document templates.

// Gets all data required for printing within a single call: object template data, binary template 
// data, and template area description.
// Used for calling print forms based on office document templates from client modules.
//
// Parameters:
//   PrintManagerName - String - a name for accessing the object manager, for example, Document.<Document name>.
//   TemplatesNames - String - names of templates used for print form generation.
//   DocumentsContent - Array - references to infobase objects (all references must be of the same type).
//
// Returns:
//  Map - a collection of references to objects and their data:
//   * Key - AnyRef - reference to an infobase object.
//   * Value - Structure - a template and data:
//       ** Key - String - a template name.
//       ** Value - Structure - object data.
//
Function TemplatesAndObjectsDataToPrint(Val PrintManagerName, Val TemplatesNames, Val DocumentsContent) Export
	
	Return PrintManagement.TemplatesAndObjectsDataToPrint(PrintManagerName, TemplatesNames, DocumentsContent);
	
EndFunction

#EndRegion

#Region Private

// Generates print forms for direct output to a printer.
//
// Detailed - for details, see PrintManager.GeneratePrintFormsForQuickPrint().
//
Function GeneratePrintFormsForQuickPrint(PrintManagerName, TemplatesNames, ObjectsArray,	PrintParameters) Export
	
	Return PrintManagement.GeneratePrintFormsForQuickPrint(PrintManagerName, TemplatesNames,
		ObjectsArray,	PrintParameters);
	
EndFunction

// Generates print forms for direct output to a printer in an ordinary application.
//
// Detailed - for details, see PrintManager.GeneratePrintFormsForQuickPrintOrdinaryApplication().
//
Function GeneratePrintFormsForQuickPrintOrdinaryApplication(PrintManagerName, TemplatesNames, ObjectsArray, PrintParameters) Export
	
	Return PrintManagement.GeneratePrintFormsForQuickPrintOrdinaryApplication(PrintManagerName, TemplatesNames,
		ObjectsArray,	PrintParameters);
	
EndFunction

// Returns True if the user is authorized to post at least one document.
Function HasRightToPost(DocumentsList) Export
	Return StandardSubsystemsServer.HasRightToPost(DocumentsList);
EndFunction

// See. PrintManager.DocumentsPackage. 
Function DocumentsPackage(SpreadsheetDocuments, PrintObjects, PrintInSets, CopiesCount = 1) Export
	
	Return PrintManagement.DocumentsPackage(SpreadsheetDocuments, PrintObjects,
		PrintInSets, CopiesCount);
	
EndFunction

Function NewPrintFormsCollection(IDs) Export
	Return Common.ValueTableToArray(PrintManagement.PreparePrintFormsCollection(IDs));
EndFunction

#EndRegion
