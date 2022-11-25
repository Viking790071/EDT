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
	
	Items.AddressingGroup.Enabled = NOT Object.Predefined;
	If NOT Object.Predefined Then
		Items.AddressingObjectsTypesGroup.Enabled = Object.UsedByAddressingObjects;
	EndIf;
	
	UpdateAvailability();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_RoleAddressing", WriteParameters, Object.Ref);
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectExchangePlanNodes") Then
		If ValueIsFilled(SelectedValue) Then
			Object.ExchangeNode = SelectedValue;
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.UsedByAddressingObjects AND NOT Object.UsedWithoutAddressingObjects Then
		For each TableRow In Object.Purpose Do
			If TypeOf(TableRow.UsersType) <> TypeOf(Catalogs.Users.EmptyRef()) Then
				PurposeDescription = Metadata.FindByType(TypeOf(TableRow.UsersType)).Presentation();
				CommonClientServer.MessageToUser( 
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль не может использоваться с обязательным уточнением для назначения: %1.'; en = 'Role cannot be used with required specification for assignment: %1.'; pl = 'Rola nie moży być używana z wymaganą specyfikacją dla przypisania: %1.';es_ES = 'El rol no puede ser utilizado con la especificación requerida para la asignación:%1.';es_CO = 'El rol no puede ser utilizado con la especificación requerida para la asignación:%1.';tr = 'Rol görev için gerekli tanımlama ile kullanılamaz: %1.';it = 'Il ruolo non può essere utilizzato con la specifica richiesta per l''assegnazione: %1.';de = 'Die Rolle kann nicht mit der erforderlichen Spezifikation für die Aufgabe zugeordnet sein: %1.'"), PurposeDescription ),,,
						"UsedByAddressingObjects", Cancel);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UsedInOtherAddressingDimensionsContextOnChange(Item)
	Items.AddressingObjectsTypesGroup.Enabled = Object.UsedByAddressingObjects;
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectAssignment(Command)
	NotifyDescription = New NotifyDescription("AfterAssignmentChoice", ThisObject);
	UsersInternalClient.SelectPurpose(ThisObject, NStr("ru = 'Выбор назначения роли'; en = 'Select role assignment'; pl = 'Wybierz przypisanie roli';es_ES = 'Seleccionar la asignación del rol';es_CO = 'Seleccionar la asignación del rol';tr = 'Rolün görevini seç';it = 'Scegliere un''assegnazione del ruolo';de = 'Rollenaufgabe auswählen'"),,, NotifyDescription);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateAvailability()
	
	Items.UsedWithoutOtherAddressingDimensionsContext.Enabled = True;
	Items.UsedInOtherAddressingDimensionsContext.Enabled = True;
	Items.MainAddressingObjectTypes.Enabled = True;
	Items.AdditionalAddressingObjectTypes.Enabled = True;
	
	If GetFunctionalOption("UseExternalUsers") Then
		If Object.Purpose.Count() > 0 Then
			SynonymArray = New Array;
			For each TableRow In Object.Purpose Do
				SynonymArray.Add(TableRow.UsersType.Metadata().Synonym);
			EndDo;
			Items.SelectPurpose.Title = StrConcat(SynonymArray, ", ");
		EndIf;
	Else
		Items.AssignmentGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAssignmentChoice(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		Modified = True;
	EndIf;
EndProcedure

#EndRegion
