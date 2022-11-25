
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If TrimAll(Object.Description)="" Then
	    Cancel = True;
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Template is not filled.'; ru = 'Шаблон не заполнен.';pl = 'Szablon nie jest wypełniony.';es_ES = 'Modelo no rellenado.';es_CO = 'Modelo no rellenado.';tr = 'Şablon doldurulmamış.';it = 'Il template non è compilato.';de = 'Die Vorlage ist nicht ausgefüllt.'");
		Message.Message();
	EndIf;	
	
EndProcedure
