
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
	
	MarkedListItemArray = CommonClientServer.MarkedItems(FieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NString = NStr("ru = 'Следует указать хотя бы одно поле'; en = 'Select one or more fields'; pl = 'Trzeba wskazać chociażby jedno pole';es_ES = 'Especificar como mínimo un campo';es_CO = 'Especificar como mínimo un campo';tr = 'En az bir alanı tanımlayın';it = 'Seleziona uno o più campi';de = 'Geben Sie mindestens ein Feld an'");
		
		CommonClientServer.MessageToUser(NString,,"FieldList");
		
		Return;
		
	EndIf;
	
	NotifyChoice(FieldList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion
