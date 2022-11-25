
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If NOT ValueIsFilled(Object.Ref)
	   AND Parameters.FillingValues.Property("Description") Then
		
		Object.Description = Parameters.FillingValues.Description;
	EndIf;
	
	If NOT Parameters.HideOwner Then
		Items.Owner.Visible = True;
	EndIf;
	
	SetTitle();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetTitle();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetTitle()
	
	AttributeValues = Common.ObjectAttributesValues(
		Object.Owner, "Title, ValueFormTitle");
	
	PropertyName = TrimAll(AttributeValues.ValueFormTitle);
	
	If NOT IsBlankString(PropertyName) Then
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (%2)'; en = '%1 (%2)'; pl = '%1 (%2)';es_ES = '%1 (%2)';es_CO = '%1 (%2)';tr = '%1 (%2)';it = '%1 (%2)';de = '%1 (%2)'"),
				Object.Description,
				PropertyName);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (Создание)'; en = '%1 (Create)'; pl = '%1 (Utworzenie)';es_ES = '%1 (Creación)';es_CO = '%1 (Creación)';tr = '%1 (Oluştur)';it = '%1 (Crea)';de = '%1 (Erstellen)'"), PropertyName);
		EndIf;
	Else
		PropertyName = String(AttributeValues.Title);
		
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (Группа значений свойства %2)'; en = '%1 (%2 property value group)'; pl = '%1 (Grupa wartości właściwości %2)';es_ES = '%1 (grupo de valores para el atributo %2)';es_CO = '%1 (grupo de valores para el atributo %2)';tr = '%1 ( %2 özniteliğinin değerler grubu)';it = '%1 (gruppo valore proprietà %2)';de = '%1 (Gruppe von Werten für das Attribut %2)'"),
				Object.Description,
				PropertyName);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Группа значений свойства %1 (Создание)'; en = '%1 property value group (Create)'; pl = 'Grupa wartości %1 właściwości (Utworzenie)';es_ES = 'Grupo de atributos para %1 (Creación)';es_CO = 'Grupo de atributos para %1 (Creación)';tr = '%1 özellik değeri grubu (Oluştur)';it = '%1 gruppo valore proprietà (creare)';de = 'Gruppe von Attributen für %1 (Erstellen)'"), PropertyName);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
