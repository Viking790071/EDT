////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

&AtServer
// Procedure saves the selected item in settings.
//
Procedure SetMainItem(SelectedItem)
	
	If SelectedItem <> DriveReUse.GetValueOfSetting("MainResponsible") Then
		DriveServer.SetUserSetting(SelectedItem, "MainResponsible");	
		DriveServer.MarkMainItemWithBold(SelectedItem, List);
	EndIf; 
		
EndProcedure

&AtClient
// Procedure - Command execution handler SetMainItem.
//
Procedure CommandSetMainItem(Command)
		
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		SetMainItem(SelectedItem);	
	EndIf; 
	
EndProcedure

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Selection of main item	
	DriveServer.MarkMainItemWithBold(DriveReUse.GetValueOfSetting("MainResponsible"), List);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	
	If Not Group Then
		
		Cancel = True;
		OpenForm("Catalog.Employees.Form.NewEmployeeCreationAssistant", New Structure("Parent", Parent), ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ClientApplicationForm")
		AND Find(ChoiceSource.FormName, "NewEmployeeCreationAssistant") > 0 
		AND ValueSelected Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion
