
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	MappingFieldsList = Parameters.MappingFieldsList;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateCommentLabelText();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MappingFieldListOnChange(Item)
	
	UpdateCommentLabelText();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunMapping(Command)
	
	NotifyChoice(MappingFieldsList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateCommentLabelText()
	
	MarkedListItemArray = CommonClientServer.MarkedItems(MappingFieldsList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NoteLabel = NStr("ru = 'Сопоставление будет выполнено только по внутренним идентификаторам объектов.'; en = 'Mapping will be performed by UUIDs only.'; pl = 'Obiekty będą mapowane wyłącznie za pomocą wewnętrznych identyfikatorów.';es_ES = 'Objetos se mapearán solo por los identificadores internos.';es_CO = 'Objetos se mapearán solo por los identificadores internos.';tr = 'Eşleştirme sadece UUID''ler ile gerçekleştirilecek.';it = 'La mappatura verrà eseguita solo per Identificativo univoco.';de = 'Mapping wird nur nach UUIDs ausgeführt.'");
		
	Else
		
		NoteLabel = NStr("ru = 'Сопоставление будет выполнено по внутренним идентификаторам объектов и по выбранным полям.'; en = 'Mapping will be performed by UUIDs and selected fields.'; pl = 'Obiekty będą mapowane przez wewnętrzne identyfikatory i wybrane pola.';es_ES = 'Objetos se mapearán por los identificadores internos y los campos seleccionados.';es_CO = 'Objetos se mapearán por los identificadores internos y los campos seleccionados.';tr = 'Eşleştirme UUID''ler ve seçilen alanlar ile gerçekleştirilecek.';it = 'La mappatura verrà eseguita per identificatore univoco e per campi selezionati.';de = 'Mapping wird nur nach UUIDs und ausgewählte Felder ausgeführt.'");
		
	EndIf;
	
EndProcedure

#EndRegion
