///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InfobasePublicationURL = Common.InfobasePublicationURL();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	GenerateRefAddress();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InfobasePublicationURLOnChange(Item)
	
	GenerateRefAddress();

EndProcedure

&AtClient
Procedure RefToObjectOnChange(Item)
	
	GenerateRefAddress();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Insert(Command)
	
	ClearMessages();
	
	Cancel = False;
	
	If IsBlankString(InfobasePublicationURL) Then
		
		MessageText = NStr("ru = 'Не указан адрес публикации информационной базы в интернете.'; en = 'Infobase publication address on the Internet is not specified.'; pl = 'Nie określono adresu publikacji bazy informacyjnej w Internecie.';es_ES = 'No se ha especificado la dirección de publicación de la base de información en Internet.';es_CO = 'No se ha especificado la dirección de publicación de la base de información en Internet.';tr = 'İnternetteki Infobase yayın adresi belirtilmedi.';it = 'L''indirizzo di pubblicazione dell''infobase su internet non è specificato.';de = 'Infobase-Veröffentlichungsadresse im Internet ist nicht angegeben.'");
		CommonClientServer.MessageToUser(MessageText,, "InfobasePublicationURL",, Cancel);
		
	EndIf;
	
	If IsBlankString(ObjectRef) Then
		
		MessageText = NStr("ru = 'Не указана внутренняя ссылка на объект.'; en = 'Internal reference to the object is not specified.'; pl = 'Nie określono odnośnika wewnętrznego do obiektu.';es_ES = 'No se ha especificado la referencia interna al objeto.';es_CO = 'No se ha especificado la referencia interna al objeto.';tr = 'Nesneye dahili referans belirtilmedi.';it = 'Il riferimento interno all''oggetto non è specificato.';de = 'Interner Hinweis auf den Objekt ist nicht angegeben.'");
		CommonClientServer.MessageToUser(MessageText,, "ObjectRef",, Cancel);
		
	EndIf;
	
	If Not Cancel Then
		NotifyChoice(GeneratedRef);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GenerateRefAddress()

	GeneratedRef = InfobasePublicationURL + "#"+ ObjectRef;

EndProcedure

#EndRegion
