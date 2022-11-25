#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	// No execute action in the data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ActionDescription = ?(Action,
		NStr("en = 'Change'; ru = 'Изменить';pl = 'Zmień';es_ES = 'Cambiar';es_CO = 'Cambiar';tr = 'Değiştir';it = 'Modifica';de = 'Ändern'", CommonClientServer.DefaultLanguageCode()),
		NStr("en = 'Open'; ru = 'Открыть';pl = 'Otwórz';es_ES = 'Abrir';es_CO = 'Abrir';tr = 'Açık';it = 'Apri';de = 'Öffnen'", CommonClientServer.DefaultLanguageCode()));
	Description = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 %2'; ru = '%1 %2';pl = '%1 %2';es_ES = '%1 %2';es_CO = '%1 %2';tr = '%1 %2';it = '%1 %2';de = '%1 %2'", CommonClientServer.DefaultLanguageCode()),
		ActionDescription,
		Common.ObjectAttributeValue(DocumentType, "Synonym"));
	
EndProcedure

#EndRegion

#EndIf