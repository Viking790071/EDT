
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ReadOnly = True;
	
	SetPropertiesTypes = PropertyManagerInternal.SetPropertiesTypes(Object.Ref);
	UseAddlAttributes = SetPropertiesTypes.AdditionalAttributes;
	UseAddlInfo  = SetPropertiesTypes.AdditionalInfo;
	
	If UseAddlAttributes AND UseAddlInfo Then
		Title = Object.Description + " " + NStr("ru = '(Группа наборов дополнительных реквизитов и сведений)'; en = '(Additional attributes and information set group)'; pl = '(Grupa zestawów dodatkowych atrybutów i informacji)';es_ES = '(Grupo de conjuntos de atributos adicionales e información)';es_CO = '(Grupo de conjuntos de atributos adicionales e información)';tr = '(Ek nitelikler ve bilgi kümeleri grubu)';it = '(Gruppo insieme attributi aggiuntivi e informazioni)';de = '(Gruppe von Sätzen zusätzlicher Attribute und Informationen)'")
		
	ElsIf UseAddlAttributes Then
		Title = Object.Description + " " + NStr("ru = '(Группа наборов дополнительных реквизитов)'; en = '(Additional attributes set group)'; pl = '(Grupa zestawów dodatkowych atrybutów)';es_ES = '(Grupo de conjuntos de atributos adicionales)';es_CO = '(Grupo de conjuntos de atributos adicionales)';tr = '(Ek nitelikler grubu)';it = '(Gruppo insieme attributi aggiuntivi)';de = '(Gruppe von Sätzen zusätzlicher Attribute)'")
		
	ElsIf UseAddlInfo Then
		Title = Object.Description + " " + NStr("ru = '(Группа наборов дополнительных сведений)'; en = '(Additional information set group)'; pl = '(Grupa dodatkowych zestawów informacji)';es_ES = '(Grupo de conjuntos de la información adicional)';es_CO = '(Grupo de conjuntos de la información adicional)';tr = '(Ek bilgi grubu)';it = '(Gruppo set informazioni aggiuntive)';de = '(Gruppe zusätzlicher Informationssätze)'")
	EndIf;
	
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
