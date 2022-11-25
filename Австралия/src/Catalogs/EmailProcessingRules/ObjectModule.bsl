///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Interactions.UserIsResponsibleForMaintainingFolders(Owner) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Данная операция доступна только ответственному за ведение папок для данной учетной записи'; en = 'This operation is available only to users responsible for the account''s folders.'; pl = 'Ta operacja jest dostępna tylko dla użytkowników odpowiedzialnych za prowadzenie folderów konta.';es_ES = 'Esta operación sólo está disponible para los usuarios responsables de las carpetas de cuenta.';es_CO = 'Esta operación sólo está disponible para los usuarios responsables de las carpetas de cuenta.';tr = 'Bu işlem sadece hesabın klasörlerinden sorumlu olan kullanıcılar tarafından yapılabilir.';it = 'Questa operazione è disponibile solamente per gli utenti responsabili delle cartelle dell''account.';de = 'Diese Operation ist nur für Benutzer verantwortlich für die Kontenordner verfügbar.'"),
			Ref,,,
			Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu na kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektaufruf auf dem Client.'");
#EndIf