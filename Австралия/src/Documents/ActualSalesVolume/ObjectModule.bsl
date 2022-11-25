#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If CounterpartyAndContractPosition = Enums.AttributeStationing.InHeader Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.Contract");
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	DriveServer.CheckInventoryForNonServices(ThisObject, Cancel);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If CounterpartyAndContractPosition = Enums.AttributeStationing.InHeader Then
		
		For Each TabularSectionRow In Inventory Do
			TabularSectionRow.Counterparty = Counterparty;
			TabularSectionRow.Contract = Contract;
		EndDo;
		
	EndIf;
	
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	Documents.ActualSalesVolume.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectActualSalesVolume(AdditionalProperties, RegisterRecords, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

#EndRegion

#EndIf