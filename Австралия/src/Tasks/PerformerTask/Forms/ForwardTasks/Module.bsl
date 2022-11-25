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
	
	FormTitleText = Parameters.FormCaption;
	DefaultTitle = IsBlankString(FormTitleText);
	If NOT DefaultTitle Then
		Title = FormTitleText;
	EndIf;
	
	TitleText = "";
	
	If Parameters.TaskCount > 1 Then
		TitleText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (%2)'; en = '%1 (%2)'; pl = '%1 (%2)';es_ES = '%1 (%2)';es_CO = '%1 (%2)';tr = '%1 (%2)';it = '%1 (%2)';de = '%1 (%2)'"),
			?(DefaultTitle, NStr("ru = 'Выбранные задачи'; en = 'Selected tasks'; pl = 'Wybrane zadania';es_ES = 'Seleccionar las tareas';es_CO = 'Seleccionar las tareas';tr = 'Seçilmiş görevler';it = 'Obiettivo selezionato';de = 'Ausgewählte Aufgaben'"), FormTitleText),
			String(Parameters.TaskCount));
	ElsIf Parameters.TaskCount = 1 Then
		TitleText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 %2'; en = '%1 %2'; pl = '%1 %2';es_ES = '%1 %2';es_CO = '%1 %2';tr = '%1 %2';it = '%1 %2';de = '%1 %2'"),
			?(DefaultTitle, NStr("ru = 'Выбранная задача'; en = 'Selected task'; pl = 'Wybrane zadanie';es_ES = 'Seleccionar la tarea';es_CO = 'Seleccionar la tarea';tr = 'Seçilmiş görev';it = 'Incarico selezionato';de = 'Ausgewählte Aufgabe'"), FormTitleText),
			String(Parameters.Task));
	Else
		Items.TitleDecoration.Visible = False;
	EndIf;
	Items.TitleDecoration.Title = TitleText;
	
	SetAddressingObjectTypes();
	SetItemsState();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If AddressingType = 0 Then
		If NOT ValueIsFilled(Performer) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не указан исполнитель задачи.'; en = 'The task assignee is not specified.'; pl = 'Nie określono wykonawcy zadania.';es_ES = 'No se especifica la tarea del ejecutor.';es_CO = 'No se especifica la tarea del ejecutor.';tr = 'Göreve atanan belirtilmedi.';it = 'Esecutore dell''obiettivo non indicato.';de = 'Der Bevollmächtiger ist nicht angegeben.'"),,,
				"Performer",
				Cancel);
		EndIf;
		Return;
	EndIf;
	
	If Role.IsEmpty() Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Не указана роль исполнителей задачи.'; en = 'The task assignee role is not specified.'; pl = 'Nie określono roli wykonawcy zadania.';es_ES = 'No se especifica el rol del ejecutor de la tarea.';es_CO = 'No se especifica el rol del ejecutor de la tarea.';tr = 'Göreve atananın rolü belirtilmedi.';it = 'Ruolo dell''esecutore dell''obiettivo non indicato.';de = 'Die Rolle vom Bevollmächtiger ist nicht angegeben.'"),,,
			"Role",
			Cancel);
		Return;
	EndIf;
	
	MainAddressingObjectTypesAreSet = UsedByAddressingObjects
		AND ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = UsedByAddressingObjects 
		AND ValueIsFilled(AdditionalAddressingObjectTypes);
	
	If MainAddressingObjectTypesAreSet AND MainAddressingObject = Undefined Then
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Поле ""%1"" не заполнено.'; en = 'The ""%1"" field is required.'; pl = 'Pole ""%1"" nie jest wypełnione.';es_ES = 'El ""%1"" campo no está rellenado.';es_CO = 'El ""%1"" campo no está rellenado.';tr = '""%1"" alanı doldurulmadı.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist nicht ausgefüllt.'"),	Role.MainAddressingObjectTypes.Description),,,
			"MainAddressingObject",
			Cancel);
		Return;
	ElsIf TypesOfAditionalAddressingObjectAreSet AND AdditionalAddressingObject = Undefined Then
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Поле ""%1"" не заполнено.'; en = 'The ""%1"" field is required.'; pl = 'Pole ""%1"" nie jest wypełnione.';es_ES = 'El ""%1"" campo no está rellenado.';es_CO = 'El ""%1"" campo no está rellenado.';tr = '""%1"" alanı doldurulmadı.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist nicht ausgefüllt.'"), Role.AdditionalAddressingObjectTypes.Description),,,
			"AdditionalAddressingObject",
			Cancel);
		Return;
	EndIf;
	
	If NOT IgnoreWarnings 
		AND NOT BusinessProcessesAndTasksServer.HasRolePerformers(Role, MainAddressingObject, AdditionalAddressingObject) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'На указанную роль не назначено ни одного исполнителя. (Чтобы проигнорировать это предупреждение, установите флажок.)'; en = 'No assignee is assigned to the specified role. (To ignore this warning, select the check box).'; pl = 'Brak wykonawcy oznacza wykonawcy do określonej roli. (Aby zignorować to ostrzeżenie, zaznacz pole wyboru).';es_ES = 'No se asigna ningún ejecutor al rol especificado. (Para ignorar esta advertencia, marque la casilla de verificación).';es_CO = 'No se asigna ningún ejecutor al rol especificado. (Para ignorar esta advertencia, marque la casilla de verificación).';tr = 'Belirtilen göreve atanan olmadı. (Bu uyarıyı görmezden gelmek için kutucuğu işaretleyin).';it = 'Non è stato assegnato alcun esecutore al ruolo indicato (spuntare la casella per ignorare questo avvertimento).';de = 'Kein Bevollmächtiger ist zur angegebenen Rolle zugeordnet. (Um diese Warnung zu ignorieren aktivieren Sie das Kontrollkästchen).'"),,,
			"Role",
			Cancel);
		Items.IgnoreWarnings.Visible = True;
	EndIf;	
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PerformerOnChange(Item)
	
	AddressingType = 0;
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	SetAddressingObjectTypes();
	SetItemsState();
	
EndProcedure

&AtClient
Procedure RoleOnChange(Item)
	
	AddressingType = 1;
	Performer = Undefined;
	MainAddressingObject = Undefined;
	AdditionalAddressingObject = Undefined;
	SetAddressingObjectTypes();
	SetItemsState();
	
EndProcedure

&AtClient
Procedure AddressingTypeOnChange(Item)
	SetItemsState();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	If NOT CheckFilling() Then
		Return;
	EndIf;
	Close(ClosingParameters());
	
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
	
	Items.Performer.MarkIncomplete = False;
	Items.Performer.AutoMarkIncomplete = AddressingType = 0;
	Items.Performer.Enabled = AddressingType = 0;
	Items.Role.MarkIncomplete = False;
	Items.Role.AutoMarkIncomplete = AddressingType <> 0;
	Items.Role.Enabled = AddressingType <> 0;
	
	MainAddressingObjectTypesAreSet = UsedByAddressingObjects
		AND ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = UsedByAddressingObjects 
		AND ValueIsFilled(AdditionalAddressingObjectTypes);
		
	Items.MainAddressingObject.Title = Role.MainAddressingObjectTypes.Description;
	Items.OneMainAddressingObject.Title = Role.MainAddressingObjectTypes.Description;
	
	If MainAddressingObjectTypesAreSet AND TypesOfAditionalAddressingObjectAreSet Then
		Items.OneAddressingObjectGroup.Visible = False;
		Items.TwoAddressingObjectsGroup.Visible = True;
	ElsIf MainAddressingObjectTypesAreSet Then
		Items.OneAddressingObjectGroup.Visible = True;
		Items.TwoAddressingObjectsGroup.Visible = False;
	Else	
		Items.OneAddressingObjectGroup.Visible = False;
		Items.TwoAddressingObjectsGroup.Visible = False;
	EndIf;
		
	Items.AdditionalAddressingObject.Title = Role.AdditionalAddressingObjectTypes.Description;
	
	Items.MainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesAreSet
		AND NOT UsedWithoutAddressingObjects;
	Items.OneMainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesAreSet
		AND NOT UsedWithoutAddressingObjects;
	Items.AdditionalAddressingObject.AutoMarkIncomplete = TypesOfAditionalAddressingObjectAreSet
		AND NOT UsedWithoutAddressingObjects;
	Items.OneMainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
	Items.MainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
	Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	
EndProcedure

&AtClient
Function ClosingParameters()
	
	Result = New Structure;
	Result.Insert("Performer", ?(ValueIsFilled(Performer), Performer, Undefined));
	Result.Insert("PerformerRole", Role);
	Result.Insert("MainAddressingObject", MainAddressingObject);
	Result.Insert("AdditionalAddressingObject", AdditionalAddressingObject);
	Result.Insert("Comment", Comment);
	
	If Result.MainAddressingObject <> Undefined AND Result.MainAddressingObject.IsEmpty() Then
		Result.MainAddressingObject = Undefined;
	EndIf;
	
	If Result.AdditionalAddressingObject <> Undefined AND Result.AdditionalAddressingObject.IsEmpty() Then
		Result.AdditionalAddressingObject = Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
