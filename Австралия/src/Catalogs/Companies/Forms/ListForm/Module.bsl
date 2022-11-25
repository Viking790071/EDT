////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

&AtServer
// Procedure saves the selected item in settings.
//
Procedure SetMainItem(SelectedItem)
	
	If SelectedItem <> DriveReUse.GetValueOfSetting("MainCompany") Then
		DriveServer.SetUserSetting(SelectedItem, "MainCompany");	
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
	
	Items.ListExchangeRatesImportProcessor.Visible = Parameters.Property("ShowExchangeRatesImportProcessorColumn");
		
	// Selection of main item
	DriveServer.MarkMainItemWithBold(DriveReUse.GetValueOfSetting("MainCompany"), List);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Items.CommandCommandSetMainItem.Visible = False;
		
	EndIf;
	
EndProcedure

#EndRegion
