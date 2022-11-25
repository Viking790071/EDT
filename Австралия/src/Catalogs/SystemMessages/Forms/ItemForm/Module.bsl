
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	MessageBody = Common.ObjectAttributeValue(Object.Ref, "MessageBody").Get();
	
	If TypeOf(MessageBody) = Type("String") Then
		
		MessageBodyPresentation = MessageBody;
		
	Else
		
		Try
			MessageBodyPresentation = Common.ValueToXMLString(MessageBody);
		Except
			MessageBodyPresentation = NStr("ru = 'Тело сообщения не может быть представлено строкой.'; en = 'Body cannot be presented as a string.'; pl = 'Zawartość wiadomości e-mail nie może być wyświetlana jako wiersz.';es_ES = 'Cuerpo del correo electrónico no puede visualizarse como una línea.';es_CO = 'Cuerpo del correo electrónico no puede visualizarse como una línea.';tr = 'E-posta gövdesi bir dize olarak görüntülenemiyor.';it = 'Il corpo del testo non può essere presentato come una stringa.';de = 'Der E-Mail-Text kann nicht als Zeichenfolge angezeigt werden.'");
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion
