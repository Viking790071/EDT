#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	AttributesToEdit = New Array;
	AttributesToEdit.Add("Details");
	AttributesToEdit.Add("EmployeeResponsible");
	AttributesToEdit.Add("CreationDate");
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowRead
	|WHERE
	|	ObjectReadingAllowed(Ref)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ObjectUpdateAllowed(Ref)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	If FormType = "ListForm" Then
		CurrentRow = CommonClientServer.StructureProperty(Parameters, "CurrentRow");
		If TypeOf(CurrentRow) = Type("CatalogRef.FileFolders") AND Not CurrentRow.IsEmpty() Then
			StandardProcessing = False;
			Parameters.Delete("CurrentRow");
			Parameters.Insert("Folder", CurrentRow);
			SelectedForm = "Catalog.Files.Form.Files";
		EndIf;
	EndIf;
EndProcedure

#EndRegion
