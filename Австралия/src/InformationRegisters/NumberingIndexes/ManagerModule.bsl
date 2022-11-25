#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Sets an index value for the passed object.
//
// Parameters:
// Object - CatalogRef.Counterparties,
//           CatalogRef.EnterpriseStructure,
//           CatalogRef.InternalDocumentsKinds,
//           CatalogRef.Companies,
//           CatalogRef.IncomingDocumentsKinds,
//           CatalogRef.ActivityIssues,
//           CatalogRef.OutgoingDocumentsKinds - a reference to the object the numbering index is being set for.
// Index - String - an index to set.
//
Procedure WriteNumberingIndex(Object, Index) Export
	
	Record = InformationRegisters.NumberingIndexes.CreateRecordManager();
	Record.Object = Object;
	Record.Read();
	
	Record.Object = Object;
	Record.Index = Index;
	Record.Write(True);
	
EndProcedure

// Returns a numbering index value of the passed object.
//
// Parameters:
// Object - CatalogRef.Counterparties,
//           CatalogRef.EnterpriseStructure,
//           CatalogRef.InternalDocumentsKinds,
//           CatalogRef.Companies,
//           CatalogRef.IncomingDocumentsKinds,
//           CatalogRef.ActivityIssues,
//           CatalogRef.OutgoingDocumentsKinds - a reference to the object the numbering index is being got for.
//
Function GetNumberingIndex(Object) Export
	
	Record = InformationRegisters.NumberingIndexes.CreateRecordManager();
	Record.Object = Object;
	Record.Read();
	
	Return TrimAll(Record.Index);
	
EndFunction

// Deletes an index value for the passed object.
//
// Parameters:
// Object - CatalogRef.Counterparties,
//           CatalogRef.EnterpriseStructure,
//           CatalogRef.InternalDocumentsKinds,
//           CatalogRef.Companies,
//           CatalogRef.IncomingDocumentsKinds,
//           CatalogRef.ActivityIssues,
//           CatalogRef.OutgoingDocumentsKinds - a reference to the object the numbering index is being deleted for.
//
Procedure DeleteNumberingIndex(Object) Export
	
	Record = InformationRegisters.NumberingIndexes.CreateRecordManager();
	Record.Object = Object;
	Record.Delete();
	
EndProcedure

#EndRegion

#Region Private

Procedure FillTypesList(TypesList) Export
	
	Types = Metadata.InformationRegisters.NumberingIndexes.Dimensions.Object.Type.Types();
	
	For Each ObjectType In Types Do
		
		ObjectRef = New(ObjectType);
		
		ObjectMetadata = ObjectRef.Metadata();
		
		Presentation = ObjectMetadata.ListPresentation;
		If IsBlankString(Presentation) Then
			Presentation = ObjectMetadata.Synonym;
		EndIf;
		
		TypesList.Add(ObjectType, Presentation);
		
	EndDo;
	
	TypesList.SortByPresentation();
	
EndProcedure

#EndRegion

#EndIf