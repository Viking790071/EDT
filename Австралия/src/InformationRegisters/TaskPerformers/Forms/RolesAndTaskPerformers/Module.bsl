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
	
	MainAddressingObject = Parameters.MainAddressingObject;
	RefreshItemsData();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_RoleAddressing" Then
		RefreshItemsData();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	AssignPerformers(Undefined);
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	AssignPerformers(Undefined);
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AllAssignmentsExecute(Command)
	
	FilterValue = New Structure("MainAddressingObject", MainAddressingObject);
	FormParameters = New Structure("Filter", FilterValue);
	OpenForm("InformationRegister.TaskPerformers.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure RefreshExecute(Command)
	RefreshItemsData();
EndProcedure

&AtClient
Procedure AssignPerformers(Command)
	
	Assignment = Items.List.CurrentData;
	If Assignment = Undefined Then
		ShowMessageBox(,NStr("ru = 'Необходимо выбрать роль в списке.'; en = 'Select a role in the list.'; pl = 'Wybierz rolę na liście';es_ES = 'Seleccione el rol en la lista.';es_CO = 'Seleccione el rol en la lista.';tr = 'Listeden rol seçin.';it = 'È necessario selezionare un ruolo nell''elenco.';de = 'Eine Rolle aus der Liste auswählen.'"));
		Return;
	EndIf;
	
	OpenForm("InformationRegister.TaskPerformers.Form.PerformersOfRoleWithAddressingObject", 
		New Structure("MainAddressingObject,Role", 
			MainAddressingObject, 
			Assignment.RoleRef));
			
EndProcedure

&AtClient
Procedure RolesList(Command)
	OpenForm("Catalog.PerformerRoles.ListForm",,ThisObject);
EndProcedure

&AtClient
Procedure OpenRoleInfo(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;	
	EndIf;
	
	ShowValue(, Items.List.CurrentData.RoleRef);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure RefreshItemsData()
	
	QuerySelection = BusinessProcessesAndTasksServer.SelectRolesWithPerformerCount(MainAddressingObject);
	ListObject = FormAttributeToValue("List");
	ListObject.Clear();
	While QuerySelection.Next() Do
		ValueType = QuerySelection.MainAddressingObjectTypes.ValueType;
		IncludesType = True;
		If MainAddressingObject <> Undefined Then
			IncludesType = ValueType <> Undefined AND ValueType.ContainsType(TypeOf(MainAddressingObject));
		EndIf;
		If IncludesType Then
			NewRow = ListObject.Add();
			FillPropertyValues(NewRow, QuerySelection, "Performers,Role,RoleRef,ExternalRole"); 
		EndIf;
	EndDo;
	ListObject.Sort("Role");
	For each ListLine In ListObject Do
		If ListLine.Performers = 0 Then
			ListLine.PerformersString = ?(ListLine.ExternalRole, NStr("ru = 'заданы в другой программе'; en = 'specified in another application'; pl = 'określono w innej aplikacji';es_ES = 'especificada en otra aplicación';es_CO = 'especificada en otra aplicación';tr = 'başka bir programda belirtildi';it = 'impostati in un altro programma';de = 'beschrieben in einer anderen Anwendung'"), NStr("ru = 'не указан'; en = 'not specified'; pl = 'nie określono';es_ES = 'no especificado';es_CO = 'no especificado';tr = 'belirtilmedi';it = 'non specificato';de = 'keine angabe'"));
			ListLine.Picture = ?(ListLine.ExternalRole, -1, 1);
		ElsIf ListLine.Performers = 1 Then
			ListLine.PerformersString = String(BusinessProcessesAndTasksServer.SelectPerformer(MainAddressingObject, ListLine.RoleRef));
			ListLine.Picture = -1;
		Else
			ListLine.PerformersString = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 чел'; en = '%1 people'; pl = '%1 osób';es_ES = '%1 personas';es_CO = '%1 personas';tr = '%1 insanlar';it = '%1 persone';de = '%1 Leute'"), String(ListLine.Performers) );
			ListLine.Picture = -1;
		EndIf;
	EndDo;
	ValueToFormAttribute(ListObject, "List");
	
EndProcedure

#EndRegion
