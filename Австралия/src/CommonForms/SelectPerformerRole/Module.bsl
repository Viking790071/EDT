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
	
	Role = Parameters.PerformerRole;
	MainAddressingObject = Parameters.MainAddressingObject;
	AdditionalAddressingObject = Parameters.AdditionalAddressingObject;
	SetAddressingObjectTypes();
	SetItemsState();
	
	If Parameters.SelectAddressingObject Then
		CurrentItem = Items.MainAddressingObject;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If UsedWithoutAddressingObjects Then
		Return;
	EndIf;
		
	MainAddressingObjectTypesAreSet = UsedByAddressingObjects AND ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = UsedByAddressingObjects AND ValueIsFilled(AdditionalAddressingObjectTypes);
	
	If MainAddressingObjectTypesAreSet AND MainAddressingObject = Undefined Then
		
		CommonClientServer.MessageToUser( 
		    StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Поле ""%1"" не заполнено.'; en = 'The ""%1"" field is required.'; pl = 'Pole ""%1"" nie jest wypełnione.';es_ES = 'El ""%1"" campo no está rellenado.';es_CO = 'El ""%1"" campo no está rellenado.';tr = '""%1"" alanı doldurulmadı.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist nicht ausgefüllt.'"), Role.MainAddressingObjectTypes.Description ),,,
				"MainAddressingObject", Cancel);
				
	ElsIf TypesOfAditionalAddressingObjectAreSet AND AdditionalAddressingObject = Undefined Then
		
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Поле ""%1"" не заполнено.'; en = 'The ""%1"" field is required.'; pl = 'Pole ""%1"" nie jest wypełnione.';es_ES = 'El ""%1"" campo no está rellenado.';es_CO = 'El ""%1"" campo no está rellenado.';tr = '""%1"" alanı doldurulmadı.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist nicht ausgefüllt.'"), Role.AdditionalAddressingObjectTypes.Description ),,, 
			"AdditionalAddressingObject", Cancel);
			
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PerformerOnChange(Item)
	
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	SetAddressingObjectTypes();
	SetItemsState();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKComplete()
	
	ClearMessages();
	If NOT CheckFilling() Then
		Return;
	EndIf;
	
	SelectionResult = ClosingParameters();
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetAddressingObjectTypes()
	
	MainAddressingObjectTypes = Role.MainAddressingObjectTypes.ValueType;
	AdditionalAddressingObjectTypes = Role.AdditionalAddressingObjectTypes.ValueType;
	UsedByAddressingObjects = Role.UsedByAddressingObjects;
	UsedWithoutAddressingObjects = Role.UsedWithoutAddressingObjects;
	
EndProcedure

&AtServer
Procedure SetItemsState()

	MainAddressingObjectTypesAreSet = UsedByAddressingObjects
		AND ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = UsedByAddressingObjects 
		AND ValueIsFilled(AdditionalAddressingObjectTypes);
		
	Items.MainAddressingObject.Title = Role.MainAddressingObjectTypes.Description;
	Items.MainAddressingObject.Enabled = MainAddressingObjectTypesAreSet; 
	Items.MainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesAreSet
		AND NOT UsedWithoutAddressingObjects;
	Items.MainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
		
	Items.AdditionalAddressingObject.Title = Role.AdditionalAddressingObjectTypes.Description;
	Items.AdditionalAddressingObject.Enabled = TypesOfAditionalAddressingObjectAreSet; 
	Items.AdditionalAddressingObject.AutoMarkIncomplete = TypesOfAditionalAddressingObjectAreSet
		AND NOT UsedWithoutAddressingObjects;
	Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	                        
EndProcedure

&AtServer
Function ClosingParameters()
	
	Result = New Structure;
	Result.Insert("PerformerRole", Role);
	Result.Insert("MainAddressingObject", MainAddressingObject);
	Result.Insert("AdditionalAddressingObject", AdditionalAddressingObject);
	
	If Result.MainAddressingObject <> Undefined AND Result.MainAddressingObject.IsEmpty() Then
		Result.MainAddressingObject = Undefined;
	EndIf;
	
	If Result.AdditionalAddressingObject <> Undefined AND Result.AdditionalAddressingObject.IsEmpty() Then
		Result.AdditionalAddressingObject = Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
