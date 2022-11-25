///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If NOT UsedByAddressingObjects AND NOT UsedWithoutAddressingObjects Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Не указаны допустимые способы назначения исполнителей на роль: совместно с объектами адресации, без них или обоими способами.'; en = 'The allowed methods for adding assignees to roles are not specified (together with the addressing objects, without them, or both ways).'; pl = 'Nie określono dozwolonych metod do dodawania wykonawców do roli (razem z obiektami adresującymi, bez nich, lub obie).';es_ES = 'No se especifican los métodos permitidos para añadir ejecutores a los roles (junto con los objetos de direccionamiento, sin ellos, o en ambos sentidos).';es_CO = 'No se especifican los métodos permitidos para añadir ejecutores a los roles (junto con los objetos de direccionamiento, sin ellos, o en ambos sentidos).';tr = 'İzin verilen role atanan atama yöntemleri belirtilmedi (gönderim hedefleri ile birlikte, olmaksızın, veya her iki şekilde).';it = 'Non sono indicati i metodi consentiti per l''assegnazione degli esecutori al ruolo: insieme agli oggetti di indirizzamento, senza di essi o con entrambi i metodi.';de = 'Die erlaubten Methoden für Hinzufügen von Aufgabenempfängern zu Rollen sind nicht angegeben (gemeinsam mit den Objekten von Adressierung, ohne diese oder beides).'"),
		 	ThisObject, "UsedWithoutAddressingObjects",,Cancel);
		Return;
	EndIf;
	
	If NOT UsedByAddressingObjects Then
		Return;
	EndIf;
	
	MainAddressingObjectTypesAreSet = MainAddressingObjectTypes <> Undefined AND NOT MainAddressingObjectTypes.IsEmpty();
	If NOT MainAddressingObjectTypesAreSet Then
		CommonClientServer.MessageToUser(NStr("ru = 'Не указаны типы основного объекта адресации.'; en = 'Types of the main addressing object are not specified.'; pl = 'Nie określono rodzajów głównych obiektów adresacji.';es_ES = 'No se especifican los tipos del objeto de direccionamiento principal.';es_CO = 'No se especifican los tipos del objeto de direccionamiento principal.';tr = 'Ana gönderim hedefinin türleri belirtilmedi.';it = 'I tipi dell''oggetto principale di indirizzamento non sono specificati.';de = 'Arten der Hauptobjekte von Adressierung sind nicht angegeben.'"),
		 	ThisObject, "MainAddressingObjectTypes",,Cancel);
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
		
	If MainAddressingObjectTypes <> Undefined AND MainAddressingObjectTypes.IsEmpty() Then
		MainAddressingObjectTypes = Undefined;
	EndIf;
	
	If AdditionalAddressingObjectTypes <> Undefined AND AdditionalAddressingObjectTypes.IsEmpty() Then
		AdditionalAddressingObjectTypes = Undefined;
	EndIf;
	
	If NOT GetFunctionalOption("UseExternalUsers") Then
		If Purpose.Find(Catalogs.Users.EmptyRef(), "UsersType") = Undefined Then
			// If external users are disconnected, the role must be assigned to users.
			Purpose.Add().UsersType = Catalogs.Users.EmptyRef();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");
#EndIf