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
	
	If Parameters.Filter.Property("Owner") Then
		
		If NOT Interactions.UserIsResponsibleForMaintainingFolders(Parameters.Filter.Owner) Then
			
			ReadOnly = True;
			
			Items.FormCommandBar.ChildItems.FormApplyRules.Visible               = False;
			Items.ItemOrderSetup.Visible = False;
			
		EndIf;
		
	Else
		
		Cancel = True;
		
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ApplyRules(Command)
	
	ClearMessages();
	
	FormParameters = New Structure;
	
	FilterItemsArray = CommonClientServer.FindFilterItemsAndGroups(InteractionsClientServer.DynamicListFilter(List), "Owner");
	If FilterItemsArray.Count() > 0 AND FilterItemsArray[0].Use
		AND ValueIsFilled(FilterItemsArray[0].RightValue) Then
		FormParameters.Insert("Account",FilterItemsArray[0].RightValue);
	Else
		CommonClientServer.MessageToUser(NStr("ru = 'Не установлен отбор по владельцу(учетной записи) правил.'; en = 'Filter by rule owner''s account is not set.'; pl = 'Nie ustawiono filtru według konta właściciela reguł.';es_ES = 'No se ha ajustado la selección por cuenta del propietario de la regla.';es_CO = 'No se ha ajustado la selección por cuenta del propietario de la regla.';tr = 'Kural sahibinin hesabına göre filtre ayarlanmadı.';it = 'La regola Filtra per nell''account del proprietario non è impostata.';de = 'Filter nach Konto des Regeleigentümers ist nicht festgelegt.'"));
		Return;
	EndIf;
	
	OpenForm("Catalog.EmailProcessingRules.Form.RulesApplication", FormParameters, ThisObject);
	
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion
