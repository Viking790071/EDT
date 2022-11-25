
#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetEnabled();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Change_Project" Then
		Items.List.CurrentRow = Parameter.Project;
		SetEnabled();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	SetEnabled();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenProjectWorkplace(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenForm("Catalog.ProjectPhases.Form.ProjectPlanForm",
		New Structure("Project", CurrentData.Ref),
		ThisObject);
	
EndProcedure

&AtClient
Procedure LoadFromTemplate(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ProjectManagementClient.LoadProjectFromTemplate(Items.List.CurrentRow);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetEnabled()
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.FormLoadFromTemplate.Enabled = (CurrentData.Status = PredefinedValue("Enum.ProjectStatuses.Open"));
	
EndProcedure

#EndRegion
