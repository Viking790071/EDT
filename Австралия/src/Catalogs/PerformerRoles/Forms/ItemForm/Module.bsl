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
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '???????? ???? ?????????? ???????????????????????????? ?? ???????????????????????? ???????????????????? ?????? ????????????????????: %1.'; en = 'Role cannot be used with required specification for assignment: %1.'; pl = 'Rola nie mo??y by?? u??ywana z wymagan?? specyfikacj?? dla przypisania: %1.';es_ES = 'El rol no puede ser utilizado con la especificaci??n requerida para la asignaci??n:%1.';es_CO = 'El rol no puede ser utilizado con la especificaci??n requerida para la asignaci??n:%1.';tr = 'Rol g??rev i??in gerekli tan??mlama ile kullan??lamaz: %1.';it = 'Il ruolo non pu?? essere utilizzato con la specifica richiesta per l''assegnazione: %1.';de = 'Die Rolle kann nicht mit der erforderlichen Spezifikation f??r die Aufgabe zugeordnet sein: %1.'"), PurposeDescription ),,,
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
	UsersInternalClient.SelectPurpose(ThisObject, NStr("ru = '?????????? ???????????????????? ????????'; en = 'Select role assignment'; pl = 'Wybierz przypisanie roli';es_ES = 'Seleccionar la asignaci??n del rol';es_CO = 'Seleccionar la asignaci??n del rol';tr = 'Rol??n g??revini se??';it = 'Scegliere un''assegnazione del ruolo';de = 'Rollenaufgabe ausw??hlen'"),,, NotifyDescription);
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
