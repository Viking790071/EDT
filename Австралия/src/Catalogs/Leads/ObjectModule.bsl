#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	// No execute action in the data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		Created = CurrentSessionDate();
	EndIf;
	
	GenerateBasicInformation();
	GenerateKanbanDescription();
	
	AdditionalProperties.Insert("IsNew", IsNew());
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	NoncheckableAttributeArray = New Array;
	
	If Not ValueIsFilled(ClosureResult)
		OR ClosureResult = Enums.LeadClosureResult.ConvertedIntoCustomer Then
		NoncheckableAttributeArray.Add("RejectionReason");
	EndIf;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("ActivityHasChanged") AND AdditionalProperties.ActivityHasChanged Then
		NewState = AdditionalProperties.NewState;
		WorkWithLeads.WriteCurrentAcrivity(Ref, NewState.Campaign, NewState.SalesRep, NewState.Activity);
	EndIf;
	
	// Duplicate rules index
	If AdditionalProperties.Property("DuplicateRulesIndexTableAddress") Then
		DuplicateRulesIndexTable = GetFromTempStorage(AdditionalProperties.DuplicateRulesIndexTableAddress);
		AdditionalProperties.Insert("DuplicateRulesIndexTable", DuplicateRulesIndexTable);
	Else
		DuplicatesBlocking.PrepareDuplicateRulesIndexTable(Ref, AdditionalProperties);
	EndIf;
	
	If AdditionalProperties.Property("ModificationTableAddress") Then
		ModificationTable = GetFromTempStorage(AdditionalProperties.ModificationTableAddress);
		DuplicatesBlocking.ChangeDuplicatesData(ModificationTable, Cancel);
	EndIf;
	
	DriveServer.ReflectDuplicateRulesIndex(AdditionalProperties, Ref, Cancel);
	
EndProcedure

#EndRegion

#Region Private

// Procedure fills an auxiliary attribute "BasicInformation"
//
Procedure GenerateBasicInformation()
	
	RowsArray = New Array;
	
	If Not IsBlankString(Description) Then
		RowsArray.Add(Description);
	EndIf;
	
	CI = ContactInformation.Unload();
	CI.Sort("Kind");
	For Each RowCI In CI Do
		If IsBlankString(RowCI.Presentation) Then
			Continue;
		EndIf;
		RowsArray.Add(RowCI.Presentation);
	EndDo;
	
	ContactsTable = Contacts.Unload();
	For Each RowContant In ContactsTable Do
		If IsBlankString(RowContant.Representation) Then
			Continue;
		EndIf;
		RowsArray.Add(RowContant.Representation);
	EndDo;
		
	If Not IsBlankString(Note) Then
		RowsArray.Add(Note);
	EndIf;
	
	BasicInformation = StrConcat(RowsArray, Chars.LF);
	
EndProcedure

// Procedure fills an auxiliary attribute "KanbanDescription"
//
Procedure GenerateKanbanDescription()
	
	LeadsArray = New Array;
	
	For Each Contact In Contacts Do
		
		If ValueIsFilled(Contact.Representation) AND Contact.Representation <> Description Then
			LeadsArray.Add(Contact.Representation);
		EndIf;
		
		For Each CILine In ContactInformation Do
			If CILine.ContactLineIdentifier <> Contact.ContactLineIdentifier Then
				Continue;
			EndIf;
			LeadsArray.Add(CILine.Presentation);
			If NOT ValueIsFilled(CILine.Type) Then
				Continue;
			EndIf;
		EndDo;
		
	EndDo;
	
	If ValueIsFilled(Note) Then
		LeadsArray.Add(Note);
	EndIf;
	
	LeadsArray.Add(Format(Created + Chars.LF, "DLF=D"));
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Tags.Description AS TagDescription
		|FROM
		|	Catalog.Tags AS Tags
		|WHERE
		|	Tags.Ref IN(&Refs)";
	
	Query.SetParameter("Refs", Tags.UnloadColumn("Tag"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		LeadsArray.Add(SelectionDetailRecords.TagDescription);
	EndDo;
	
	KanbanDescription = StrConcat(LeadsArray, Chars.LF);
	
EndProcedure

#EndRegion

#EndIf