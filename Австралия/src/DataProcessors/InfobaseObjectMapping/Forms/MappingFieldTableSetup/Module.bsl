
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FieldList = Parameters.FieldList;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Apply(Command)
	
	Cancel = False;
	
	MarkedListItemArray = CommonClientServer.MarkedItems(FieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NString = NStr("ru = 'Следует указать хотя бы одно поле'; en = 'Select one or more fields'; pl = 'Trzeba wskazać chociażby jedno pole';es_ES = 'Especificar como mínimo un campo';es_CO = 'Especificar como mínimo un campo';tr = 'En az bir alanı tanımlayın';it = 'Seleziona uno o più campi';de = 'Geben Sie mindestens ein Feld an'");
		
		CommonClientServer.MessageToUser(NString,,"FieldList",, Cancel);
		
	ElsIf MarkedListItemArray.Count() > MaxUserFields() Then
		
		// The value must not exceed the specified number.
		MessageString = NStr("ru = 'Уменьшите количество полей (можно выбирать не более [FieldsCount] полей)'; en = 'Reduce the number of fields (you can select no more than [FieldsCount] fields)'; pl = 'Zmniejszcie ilość pól (można wybierać nie więcej [FieldsCount] pól)';es_ES = 'Reducir el número de campos (se puede seleccionar no más de [FieldsCount] campos)';es_CO = 'Reducir el número de campos (se puede seleccionar no más de [FieldsCount] campos)';tr = 'Alan sayısını azaltın (en fazla [FieldsCount] alan seçin)';it = 'Ridurre il numero dei campi (è possibile selezionare fino a [FieldsCount] campi)';de = 'Reduzieren der Anzahl der Felder (Sie können nicht mehr als [FieldsCount] Felder auswählen)'");
		MessageString = StrReplace(MessageString, "[FieldsCount]", String(MaxUserFields()));
		CommonClientServer.MessageToUser(MessageString,,"FieldList",, Cancel);
		
	EndIf;
	
	If Not Cancel Then
		
		NotifyChoice(FieldList.Copy());
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function MaxUserFields()
	
	Return DataExchangeClient.MaxCountOfObjectsMappingFields();
	
EndFunction

#EndRegion
