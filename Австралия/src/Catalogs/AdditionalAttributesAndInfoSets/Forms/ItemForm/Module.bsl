
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
		Title = Object.Description + " " + NStr("ru = '(Набор дополнительных реквизитов и сведений)'; en = '(Additional attributes and information set)'; pl = '(Zestaw dodatkowych atrybutów i informacji)';es_ES = '(Grupo de atributos adicionales e información)';es_CO = '(Grupo de atributos adicionales e información)';tr = '(Ek nitelikler ve bilgi kümesi)';it = '(Set di attributi e informazioni aggiuntivi)';de = '(Sätze von zusätzlichen Attributen und Informationen)'")
		
	ElsIf UseAddlAttributes Then
		Title = Object.Description + " " + NStr("ru = '(Набор дополнительных реквизитов)'; en = '(Additional attributes set)'; pl = '(Dodatkowy zestaw atrybutów)';es_ES = '(Conjunto de atributos adicionales)';es_CO = '(Conjunto de atributos adicionales)';tr = '(Ek nitelikler kümesi)';it = '(Insieme di attributi aggiuntivi)';de = '(Zusätzlicher Attribut Satz)'")
		
	ElsIf UseAddlInfo Then
		Title = Object.Description + " " + NStr("ru = '(Набор дополнительных сведений)'; en = '(Additional information set)'; pl = '(Zestaw dodatkowych informacji)';es_ES = '(Conjunto de la información adicional)';es_CO = '(Conjunto de la información adicional)';tr = '(Ek bilgi kümesi)';it = '(Informazioni set supplementare)';de = '(Weitere Informationen Satz)'")
	EndIf;
	
	If NOT UseAddlAttributes AND Object.AdditionalAttributes.Count() = 0 Then
		Items.AdditionalAttributes.Visible = False;
	EndIf;
	
	If NOT UseAddlInfo AND Object.AdditionalInfo.Count() = 0 Then
		Items.AdditionalInfo.Visible = False;
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
