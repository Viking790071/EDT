///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillSubjectsTypesTable();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	SetTableFilter(ThisObject);
	
	CurrentSubjectType = Settings.Get("CurrentSubjectType");
	If ValueIsFilled(CurrentSubjectType) Then
		
		FoundRows =  SubjectsTypesTable.FindRows(New Structure("SubjectType", CurrentSubjectType));
		
		If FoundRows.Count() > 0 Then
			Items.SubjectsTypesTable.CurrentRow = FoundRows[0].GetID();
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region SubjectTypesFormsTablesItemsEventsHandlers

&AtClient
Procedure SubjectsTypesTableValueSelection(Item, Value, StandardProcessing)
	
	SelectAndClose();
	
EndProcedure

&AtClient
Procedure SubjectsTypesTableOnActivateRow(Item)
	
	CurrentData = Items.SubjectsTypesTable.CurrentData;
	
	If CurrentData <> Undefined Then
		CurrentSubjectType = CurrentData.SubjectType;
	EndIf;
	
EndProcedure

&AtClient
Procedure DontDisplayInteractionsOnChange(Item)
	
	SetTableFilter(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	SelectAndClose();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillSubjectsTypesTable()

	ListOfAvailableSubjectsTypes = Interactions.ListOfAvailableSubjectsTypes();
	ListOfAvailableSubjectsTypes.SortByPresentation();
	
	For Each ListItem In ListOfAvailableSubjectsTypes Do 
		
		NewRow = SubjectsTypesTable.Add();
		NewRow.TypePresentation       = ListItem.Presentation;
		NewRow.SubjectType             = ListItem.Value;
		NewRow.IsInteraction = ListItem.Check;
		
	EndDo;

EndProcedure

&AtClient
Procedure SelectAndClose()
	
	CurrentData = Items.SubjectsTypesTable.CurrentData;
	
	If CurrentData = Undefined Then
		Close();
	EndIf;
	
	NotifyChoice(CurrentData.SubjectType);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetTableFilter(Form)

	If Form.DontDisplayInteractions Then
		RowsFilter = New Structure("IsInteraction", False);
		Form.Items.SubjectsTypesTable.RowFilter = New FixedStructure(RowsFilter);
	Else
		Form.Items.SubjectsTypesTable.RowFilter = Undefined;
	EndIf;

EndProcedure

#EndRegion
