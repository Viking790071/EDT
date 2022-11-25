
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
	
	If TypeOf(Parameters.ShowWeight) = Type("Boolean") Then
		ShowWeight = Parameters.ShowWeight;
	Else
		ShowWeight = Common.ObjectAttributeValue(Object.Owner, "AdditionalValuesWithWeight");
	EndIf;
	
	If ShowWeight = True Then
		Items.Weight.Visible = True;
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "ValuesWithWeight");
	Else
		Items.Weight.Visible = False;
		Object.Weight = 0;
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "ValuesWithoutWeight");
	EndIf;
	
	SetTitle();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Change_ValueIsCharacterizedByWeightCoefficient"
	   AND Source = Object.Owner Then
		
		If Parameter = True Then
			Items.Weight.Visible = True;
		Else
			Items.Weight.Visible = False;
			Object.Weight = 0;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetTitle();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_ObjectPropertyValues",
		New Structure("Ref", Object.Ref), Object.Ref);
	
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
			Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (Значение свойства %2)'; en = '%1 (%2 property value)'; pl = '%1 (Znaczenie właściwości %2)';es_ES = '%1 (valor del atributo %2)';es_CO = '%1 (valor del atributo %2)';tr = '%1 (özniteliğin değeri %2)';it = '%1 (%2 valore proprietà)';de = '%1 (Wert des Attributs %2)'"),
				Object.Description,
				PropertyName);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Значение свойства %1 (Создание)'; en = '%1 property value (Create)'; pl = 'Znaczenie właściwości %1 (Utwórz)';es_ES = 'Valor del atributo %1 (Crear)';es_CO = 'Valor del atributo %1 (Crear)';tr = '%1 özellik değeri (Oluştur)';it = '%1 valore proprietà (Crea)';de = 'Wert des Attributs %1 (Erstellen)'"), PropertyName);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
